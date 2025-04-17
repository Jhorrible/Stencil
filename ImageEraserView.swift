import SwiftUI
import UIKit
import AVFoundation
import PhotosUI

// MARK: - SwiftUI Main View
struct ImageEraser: View {
    @Environment(\.presentationMode) var presentationMode
    @State private var brushSize: CGFloat = 20.0
    @State private var uiImage: UIImage
    @State private var showingPhotoCropView: Bool = false
    @GestureState private var dragOffset = CGSize.zero
    @State private var imageFrame: CGRect = .zero // Store the image frame

    // Completion handler to return the edited image
    var onSave: (UIImage) -> Void

    init(image: UIImage, onSave: @escaping (UIImage) -> Void) {
        _uiImage = State(initialValue: image)
        self.onSave = onSave
    }

    var body: some View {
        ZStack {
            // Main layout
            HStack(spacing: 0) {
                // Image container - proper sizing
                GeometryReader { geometry in
                    UIKitEraserView(image: $uiImage, brushSize: $brushSize, imageFrame: $imageFrame)
                        .frame(width: geometry.size.width, height: geometry.size.height)
                        .background(Color.white)
                        .cornerRadius(8)
                        .onAppear {
                            // Calculate and store the initial image frame
                            let imageSize = uiImage.size
                            let viewSize = geometry.size
                            let imageAspect = imageSize.width / imageSize.height
                            let viewAspect = viewSize.width / viewSize.height

                            var scaledImageSize = CGSize.zero
                            if imageAspect > viewAspect {
                                scaledImageSize = CGSize(width: viewSize.width, height: viewSize.width / imageAspect)
                            } else {
                                scaledImageSize = CGSize(width: viewSize.height * imageAspect, height: viewSize.height)
                            }

                            let imageX = (viewSize.width - scaledImageSize.width) / 2
                            let imageY = (viewSize.height - scaledImageSize.height) / 2
                            imageFrame = CGRect(x: imageX, y: imageY, width: scaledImageSize.width, height: scaledImageSize.height)
                        }
                }
                .frame(height: UIScreen.main.bounds.height * 0.6)
                .padding(.horizontal, 8)
                .sheet(isPresented: $showingPhotoCropView) {
                    PhotoCropView(image: uiImage) { croppedImage in
                        uiImage = croppedImage
                        onSave(croppedImage)
                    }
                }

                // Tools container - now with auto-sizing height
                VStack(alignment: .center, spacing: 15) {
                    Spacer().frame(height: 15) // Top spacing

                    // Tools
                    VStack(spacing: 12) {
                        Button(action: {
                            showingPhotoCropView = true
                        }) {
                            Image(systemName: "crop")
                                .font(.system(size: 20))
                                .foregroundColor(.gray)
                                .frame(width: 40, height: 40)
                                .background(Color(UIColor.systemBackground))
                                .cornerRadius(8)
                        }

                        Image(systemName: "wand.and.stars")
                            .font(.system(size: 20))
                            .foregroundColor(.gray)
                            .frame(width: 40, height: 40)
                            .background(Color(UIColor.systemBackground))
                            .cornerRadius(8)

                        Image(systemName: "slider.horizontal.3")
                            .font(.system(size: 20))
                            .foregroundColor(.gray)
                            .frame(width: 40, height: 40)
                            .background(Color(UIColor.systemBackground))
                            .cornerRadius(8)
                    }

                    Divider().padding(.vertical, 8)

                    // Save and Cancel buttons
                    VStack(spacing: 12) {
                        Button(action: {
                            onSave(uiImage)
                            presentationMode.wrappedValue.dismiss()
                        }) {
                            Image(systemName: "arrow.down.circle")
                                .font(.system(size: 20))
                                .foregroundColor(.black)
                                .frame(width: 40, height: 40)
                                .background(Color(UIColor.systemBackground))
                                .cornerRadius(8)
                        }

                        Button(action: {
                            presentationMode.wrappedValue.dismiss()
                        }) {
                            Image(systemName: "x.circle")
                                .font(.system(size: 20))
                                .foregroundColor(.black)
                                .frame(width: 40, height: 40)
                                .background(Color(UIColor.systemBackground))
                                .cornerRadius(8)
                        }
                    }

                    Spacer().frame(height: 15) // Bottom spacing
                }
                .frame(width: 60) // Keep width at 60
                .padding(.vertical) // Add vertical padding
                .background(Color(UIColor.systemGray6))
                .cornerRadius(8)
            }

            // Top Right Overlay for Brush Controls
            VStack {
                HStack {
                    Spacer()
                    HStack {
                        Text("Brush Size: \(Int(brushSize))")
                            .font(.subheadline)
                            .foregroundColor(.black)
                        Slider(value: $brushSize, in: 5...500)
                            .frame(width: 100)
                    }
                    .padding(8)
                    .background(Color.clear)
                    .cornerRadius(8)
                    .padding(.top, 19)
                    .padding(.trailing, 16)
                }
                Spacer()
            }
            .edgesIgnoringSafeArea(.top)
        }
        .edgesIgnoringSafeArea(.all)
        .navigationBarHidden(true)
    }
}



// MARK: - PhotoCropView Implementation
struct PhotoCropView: View {
    @State private var selectedItem: PhotosPickerItem? = nil
    @State private var image: UIImage? = nil
    @State private var isCropping: Bool = true // Start in cropping mode
    @State private var cropRect: CGRect = .zero
    @State private var imageSize: CGSize = .zero
    @State private var imageScale: CGFloat = 1.0
    @State private var containerSize: CGSize = .zero
    @State private var currentImageFrame: CGRect = .zero
    @Environment(\.presentationMode) var presentationMode
    var onSave: ((UIImage) -> Void)?

    init(image: UIImage? = nil, onSave: ((UIImage) -> Void)? = nil) {
        self._image = State(initialValue: image)
        self.onSave = onSave
    }

    var body: some View {
        VStack {
            ZStack {
                if let image = image {
                    GeometryReader { geometry in
                        let frame = geometry.frame(in: .local)
                        ZStack {
                            // The full image (always visible)
                            Image(uiImage: image)
                                .resizable()
                                .scaledToFit()
                                .scaleEffect(imageScale)
                                .onAppear {
                                    imageSize = calculateImageSize(frame: frame, image: image)
                                    resetCropRect()
                                    containerSize = frame.size
                                    currentImageFrame = frame
                                }
                                .onChange(of: geometry.size) { newSize in
                                    let newFrame = geometry.frame(in: .local)
                                    imageSize = calculateImageSize(frame: newFrame, image: image)
                                    // Keep crop rect within bounds on resize
                                    adjustCropRectToBounds()
                                    if containerSize != newSize {
                                        resetCropRect()
                                        containerSize = newSize
                                    }
                                    currentImageFrame = newFrame
                                }

                            // Overlay when cropping (doesn't clip the image)
                            if isCropping {
                                CropOverlayView(cropRect: $cropRect, imageSize: imageSize)
                            }
                        }
                        .clipShape(Rectangle()) // Clip the ZStack
                    }
                    .gesture(
                        MagnificationGesture()
                            .onChanged { value in
                                imageScale = value.magnitude
                            }
                    )
                } else {
                    Text("Choose a photo")
                        .font(.title)
                }
            }
            .padding()

            HStack {
                if isCropping {
                    Button("Save") {
                        saveCroppedImage()
                    }
                    .padding()

                    Button("Cancel") {
                        isCropping = false
                        resetImageTransform()
                        presentationMode.wrappedValue.dismiss()
                    }
                    .padding()
                } else {
                    if image == nil {
                        PhotosPicker("Select Photo", selection: $selectedItem, matching: .images)
                            .onChange(of: selectedItem) { newItem in
                                if let newItem = newItem {
                                    Task {
                                        if let data = try? await newItem.loadTransferable(type: Data.self),
                                           let uiImage = UIImage(data: data) {
                                            image = normalizeImageOrientation(uiImage)
                                            resetImageTransform()
                                        }
                                    }
                                }
                            }
                            .padding()
                    }

                    Button("Done") {
                        if let image = image, let onSave = onSave {
                            onSave(image)
                        }
                        presentationMode.wrappedValue.dismiss()
                    }
                    .padding()
                }
            }
        }
    }

    private func getCurrentImageFrame() -> CGRect? {
        return currentImageFrame
    }

    private func resetImageTransform() {
        imageScale = 1.0
    }

    private func resetCropRect() {
        guard imageSize != .zero else { return }
        let initialWidth = min(200, imageSize.width * 0.8)
        let initialHeight = min(200, imageSize.height * 0.8)
        cropRect = CGRect(
            x: (imageSize.width - initialWidth) / 2,
            y: (imageSize.height - initialHeight) / 2,
            width: initialWidth,
            height: initialHeight
        )
    }

    private func saveCroppedImage() {
        guard let uiImage = image else { return }
        guard let cgImage = uiImage.cgImage else { return }

        let originalWidth = CGFloat(cgImage.width)
        let originalHeight = CGFloat(cgImage.height)
        let scaleX = originalWidth / imageSize.width
        let scaleY = originalHeight / imageSize.height

        let scaledCropRect = CGRect(
            x: cropRect.origin.x / imageScale,
            y: cropRect.origin.y / imageScale,
            width: cropRect.width / imageScale,
            height: cropRect.height / imageScale
        )

        let finalCropRect = CGRect(
            x: scaledCropRect.origin.x * scaleX,
            y: scaledCropRect.origin.y * scaleY,
            width: scaledCropRect.width * scaleX,
            height: scaledCropRect.height * scaleY
        )

        let boundedCropRect = CGRect(
            x: max(0, finalCropRect.origin.x),
            y: max(0, finalCropRect.origin.y),
            width: min(finalCropRect.width, originalWidth - finalCropRect.origin.x),
            height: min(finalCropRect.height, originalHeight - finalCropRect.origin.y)
        )

        if let croppedCGImage = cgImage.cropping(to: boundedCropRect) {
            let croppedImage = UIImage(cgImage: croppedCGImage, scale: uiImage.scale, orientation: uiImage.imageOrientation)
            image = croppedImage

            // Call the onSave callback if provided
            if let onSave = onSave {
                onSave(croppedImage)
            }
        }

        isCropping = false
        resetImageTransform()
    }

    private func calculateImageSize(frame: CGRect, image: UIImage) -> CGSize {
        let imageAspect = image.size.width / image.size.height
        let frameAspect = frame.size.width / frame.size.height

        if imageAspect > frameAspect {
            let width = frame.size.width
            let height = width / imageAspect
            return CGSize(width: width, height: height)
        } else {
            let height = frame.size.height
            let width = height * imageAspect
            return CGSize(width: width, height: height)
        }
    }

    private func normalizeImageOrientation(_ image: UIImage) -> UIImage {
        if image.imageOrientation == .up {
            return image
        }
        UIGraphicsBeginImageContextWithOptions(image.size, false, image.scale)
        image.draw(in: CGRect(origin: .zero, size: image.size))
        let normalizedImage = UIGraphicsGetImageFromCurrentImageContext()
        UIGraphicsEndImageContext()
        return normalizedImage ?? image
    }

    private func adjustCropRectToBounds() {
        let scaledWidth = imageSize.width * imageScale
        let scaledHeight = imageSize.height * imageScale

        cropRect.origin.x = max(0, min(cropRect.origin.x, scaledWidth - cropRect.width))
        cropRect.origin.y = max(0, min(cropRect.origin.y, scaledHeight - cropRect.height))
        cropRect.size.width = min(cropRect.width, scaledWidth)
        cropRect.size.height = min(cropRect.height, scaledHeight)
    }
}

// CropOverlayView for PhotoCropView
private struct CropOverlayView: View {
    @Binding var cropRect: CGRect
    let imageSize: CGSize

    var body: some View {
        ZStack {
            Rectangle()
                .fill(Color.black.opacity(0.5))
                .frame(width: imageSize.width, height: imageSize.height)
                .allowsHitTesting(false)

            Path { path in
                path.addRect(CGRect(origin: .zero, size: imageSize))
                path.addRect(cropRect)
            }
            .fill(Color.black.opacity(0.5), style: FillStyle(eoFill: true))
            .clipped()

            Rectangle()
                .stroke(Color.white, style: StrokeStyle(lineWidth: 2, dash: [5]))
                .frame(width: cropRect.width, height: cropRect.height)
                .position(x: cropRect.midX, y: cropRect.midY)

            ForEach(HandlePosition.allCases, id: \.self) { handle in
                HandleView(position: handle, cropRect: $cropRect, imageSize: imageSize)
                    .zIndex(1)
            }
        }
        .frame(width: imageSize.width, height: imageSize.height, alignment: .topLeading)
    }
}

// Crop Handle Enum
private enum HandlePosition: CaseIterable, Hashable {
    case topLeft, topRight, bottomLeft, bottomRight
}

// Crop Handle View
private struct HandleView: View {
    let position: HandlePosition
    @Binding var cropRect: CGRect
    let imageSize: CGSize

    @State private var previousDragTranslation: CGSize = .zero

    var body: some View {
        if position == .bottomRight {
            Image(systemName: "arrow.up.left.and.down.right.and.arrow.up.right.and.down.left")
                .resizable()
                .foregroundColor(.white)
                .frame(width: 20, height: 20)
                .position(handlePosition())
                .gesture(
                    DragGesture(minimumDistance: 0)
                        .onChanged { value in
                            let translation = value.translation
                            moveCropRect(with: translation)
                            previousDragTranslation = translation
                        }
                        .onEnded { _ in
                            previousDragTranslation = .zero
                        }
                )
        } else {
            Rectangle()
                .fill(Color.white)
                .frame(width: 15, height: 15)
                .position(handlePosition())
                .gesture(
                    DragGesture(minimumDistance: 0)
                        .onChanged { value in
                            let translation = value.translation
                            resizeCropRect(with: CGSize(width: translation.width - previousDragTranslation.width, height: translation.height - previousDragTranslation.height))
                            previousDragTranslation = translation
                        }
                        .onEnded { _ in
                            previousDragTranslation = .zero
                        }
                )
        }
    }

    private func handlePosition() -> CGPoint {
        switch position {
        case .topLeft:
            return CGPoint(x: cropRect.minX, y: cropRect.minY)
        case .topRight:
            return CGPoint(x: cropRect.maxX, y: cropRect.minY)
        case .bottomLeft:
            return CGPoint(x: cropRect.minX, y: cropRect.maxY)
        case .bottomRight:
            return CGPoint(x: cropRect.maxX, y: cropRect.maxY)
        }
    }

    private func resizeCropRect(with translation: CGSize) {
        var newRect = cropRect

        switch position {
        case .topLeft:
            newRect.origin.x += translation.width
                        newRect.origin.y += translation.height
                        newRect.size.width -= translation.width
                        newRect.size.height -= translation.height
                    case .topRight:
                        newRect.origin.y += translation.height
                        newRect.size.width += translation.width
                        newRect.size.height -= translation.height
                    case .bottomLeft:
                        newRect.origin.x += translation.width
                        newRect.size.width -= translation.width
                        newRect.size.height += translation.height
                    case .bottomRight:
                        newRect.size.width += translation.width
                        newRect.size.height += translation.height
                    }

                    // Ensure minimum size
                    if newRect.width < 50 {
                        let diff = 50 - newRect.width
                        if position == .topLeft || position == .bottomLeft {
                            newRect.origin.x -= diff
                        }
                        newRect.size.width = 50
                    }
                    if newRect.height < 50 {
                        let diff = 50 - newRect.height
                        if position == .topLeft || position == .topRight {
                            newRect.origin.y -= diff
                        }
                        newRect.size.height = 50
                    }

                    // Keep within image bounds
                    newRect.origin.x = max(0, min(newRect.origin.x, imageSize.width - newRect.size.width))
                    newRect.origin.y = max(0, min(newRect.origin.y, imageSize.height - newRect.size.height))
                    newRect.size.width = max(50, min(newRect.size.width, imageSize.width - newRect.origin.x))
                    newRect.size.height = max(50, min(newRect.size.height, imageSize.height - newRect.origin.y))

                    cropRect = newRect
                }

                private func moveCropRect(with translation: CGSize) {
                    var newRect = cropRect
                    let deltaX = translation.width - previousDragTranslation.width
                    let deltaY = translation.height - previousDragTranslation.height
                    newRect.origin.x += deltaX
                    newRect.origin.y += deltaY

                    // Keep within image bounds
                    newRect.origin.x = max(0, min(newRect.origin.x, imageSize.width - newRect.size.width))
                    newRect.origin.y = max(0, min(newRect.origin.y, imageSize.height - newRect.size.height))

                    cropRect = newRect
                    previousDragTranslation = translation
                }
            }

            // MARK: - UIViewRepresentable wrapper for a UIKit-based eraser
            struct UIKitEraserView: UIViewRepresentable {
                @Binding var image: UIImage
                @Binding var brushSize: CGFloat
                @Binding var imageFrame: CGRect // Receive the calculated image frame from SwiftUI

                func makeUIView(context: Context) -> UIKitEraser {
                    let eraser = UIKitEraser(image: image, brushSize: brushSize, imageFrame: imageFrame)
                    eraser.delegate = context.coordinator
                    return eraser
                }

                func updateUIView(_ uiView: UIKitEraser, context: Context) {
                    uiView.brushSize = brushSize
                    uiView.imageFrame = imageFrame // Update the image frame in UIKitEraser
                    uiView.setNeedsDisplay() // Ensure redraw for image changes
                }

                func makeCoordinator() -> Coordinator {
                    Coordinator(parent: self)
                }

                class Coordinator: NSObject, UIKitEraserDelegate {
                    var parent: UIKitEraserView

                    init(parent: UIKitEraserView) {
                        self.parent = parent
                    }

                    func imageDidChange(_ newImage: UIImage) {
                        parent.image = newImage
                    }
                }
            }

            // Protocol for UIKitEraser delegate
            @objc protocol UIKitEraserDelegate: AnyObject {
                @objc optional func imageDidChange(_ newImage: UIImage)
            }

            // Custom UIKit view for image erasing
            class UIKitEraser: UIView {
                // Image properties
                private var originalImage: UIImage
                private var workingImage: UIImage
                private var imageView: UIImageView!
                private var containerView: UIView!
                private var eraseDelayTimer: Timer?
                private var tempEraseLayer: CAShapeLayer!
                var imageFrame: CGRect = .zero // Receive image frame from SwiftUI

                // Drawing properties
                var brushSize: CGFloat {
                    didSet {
                        updateBrushIndicator()
                    }
                }
                private var brushIndicator: UIView!

                private var activeEraseTouch: UITouch?

                // Gesture state
                private var lastPoint: CGPoint?
                private var touchStarted = false

                // New state variables for finger and pen tracking
                private var isFingerTouching: Bool = false
                private var isPenTouching: Bool = false

                // Transform state
                private var currentScale: CGFloat = 1.0
                private var currentTranslation: CGPoint = .zero
                private var currentRotation: CGFloat = 0.0

                // Delegate
                weak var delegate: UIKitEraserDelegate?

                // Gesture recognizers
                private var pinchGesture: UIPinchGestureRecognizer!
                private var panGesture: UIPanGestureRecognizer!
                private var rotationGesture: UIRotationGestureRecognizer!

                // Initialization
                init(image: UIImage, brushSize: CGFloat, imageFrame: CGRect) {
                    self.originalImage = image
                    self.workingImage = image
                    self.brushSize = brushSize
                    self.imageFrame = imageFrame
                    super.init(frame: .zero)
                    setupUI()
                    setupGestures()
                }

                required init?(coder: NSCoder) {
                    fatalError("init(coder:) has not been implemented")
                }

                // MARK: - Setup Methods
                private func setupUI() {
                    containerView = UIView()
                    containerView.backgroundColor = .clear
                    containerView.clipsToBounds = true
                    addSubview(containerView)

                    imageView = UIImageView(image: workingImage)
                    imageView.contentMode = .scaleAspectFit
                    imageView.backgroundColor = .clear
                    imageView.isUserInteractionEnabled = true
                    containerView.addSubview(imageView)

                    brushIndicator = UIView()
                    brushIndicator.layer.borderWidth = 2
                    brushIndicator.layer.borderColor = UIColor.green.cgColor
                    brushIndicator.backgroundColor = UIColor.clear
                    brushIndicator.isUserInteractionEnabled = false
                    brushIndicator.isHidden = true
                    addSubview(brushIndicator)

                    updateBrushIndicator()

                    tempEraseLayer = CAShapeLayer()
                    tempEraseLayer.fillColor = UIColor.clear.cgColor
                    tempEraseLayer.strokeColor = UIColor.clear.cgColor
                    tempEraseLayer.lineWidth = 0
                    tempEraseLayer.lineCap = .round
                    imageView.layer.addSublayer(tempEraseLayer)
                }

                private func setupGestures() {
                    pinchGesture = UIPinchGestureRecognizer(target: self, action: #selector(handlePinch(_:)))
                    panGesture = UIPanGestureRecognizer(target: self, action: #selector(handlePan(_:)))
                    rotationGesture = UIRotationGestureRecognizer(target: self, action: #selector(handleRotation(_:)))

                    // Set minimum touch requirements for gestures that should only work with 2+ fingers
                    panGesture.minimumNumberOfTouches = 2

                    // Set delegates for gesture recognizers
                    pinchGesture.delegate = self
                    panGesture.delegate = self
                    rotationGesture.delegate = self

                    // Add gesture recognizers to view
                    containerView.addGestureRecognizer(pinchGesture)
                    containerView.addGestureRecognizer(panGesture)
                    containerView.addGestureRecognizer(rotationGesture)

                    self.isMultipleTouchEnabled = true
                }

                private func updateBrushIndicator() {
                    brushIndicator.frame = CGRect(x: 0, y: 0, width: brushSize, height: brushSize)
                    brushIndicator.layer.cornerRadius = brushSize / 2
                }

                private func calculateImageFrame() -> CGRect {
                    return imageFrame // Use the frame passed from SwiftUI
                }

                // MARK: - Gesture Handlers
                @objc private func handlePinch(_ gesture: UIPinchGestureRecognizer) {
                    guard let view = gesture.view else { return }

                    if gesture.state == .began || gesture.state == .changed {
                        let scale = gesture.scale
                        imageView.transform = imageView.transform.scaledBy(x: scale, y: scale)
                        gesture.scale = 1.0 // Reset scale to avoid compounding
                    }

                    if gesture.state == .ended {
                        currentScale = imageView.transform.scale // Save the current scale
                    }
                }

                @objc private func handlePan(_ gesture: UIPanGestureRecognizer) {
                    let translation = gesture.translation(in: containerView)

                    if gesture.state == .changed {
                        // Translate the image
                        imageView.transform = imageView.transform.translatedBy(x: translation.x, y: translation.y)
                        gesture.setTranslation(.zero, in: containerView) // Reset translation to avoid compounding
                    }

                    if gesture.state == .ended {
                        // Save the current translation
                        currentTranslation.x += translation.x
                        currentTranslation.y += translation.y
                    }
                }

                @objc private func handleRotation(_ gesture: UIRotationGestureRecognizer) {
                    if gesture.state == .changed {
                        imageView.transform = imageView.transform.rotated(by: gesture.rotation)
                        gesture.rotation = 0 // Reset rotation to avoid compounding
                    }

                    if gesture.state == .ended {
                        currentRotation += gesture.rotation
                    }
                }

                // MARK: - Layout
                override func layoutSubviews() {
                    super.layoutSubviews()
                    containerView.frame = bounds
                    imageView.frame = containerView.bounds
                    tempEraseLayer.frame = imageView.bounds // Ensure temp layer has the same bounds
                }

                // MARK: - Touch Handling for Erasing
                override func touchesBegan(_ touches: Set<UITouch>, with event: UIEvent?) {
                    super.touchesBegan(touches, with: event)

                    if isGestureRecognizerActive() {
                        return
                    }

                    guard let touch = touches.first else { return }

                    // If there's already an active touch, ignore any others
                    if activeEraseTouch != nil {
                        return
                    }

                    activeEraseTouch = touch
                    lastPoint = touch.location(in: self.containerView)
                    touchStarted = true

                    updateBrushPosition(at: lastPoint!)
                    brushIndicator.isHidden = false

                    if touch.type == .stylus {
                        isPenTouching = true
                    } else {
                        isFingerTouching = true
                    }

                    tempEraseLayer.path = nil
                    eraseAt(viewPoint: lastPoint!)
                }

                override func touchesMoved(_ touches: Set<UITouch>, with event: UIEvent?) {
                    super.touchesMoved(touches, with: event)

                    // Skip if we're not in erase mode
                    if !touchStarted {
                        return
                    }

                    guard let touch = touches.first, touch == activeEraseTouch, let lastPoint = self.lastPoint else {
                        return
                    }

                    let currentPoint = touch.location(in: containerView)
                    updateBrushPosition(at: currentPoint)

                    // Ensure we have a valid last point
                    if lastPoint.x.isNaN || lastPoint.y.isNaN ||
                        currentPoint.x.isNaN || currentPoint.y.isNaN {
                        self.lastPoint = currentPoint
                        return
                    }

                    // Begin drawing
                    UIGraphicsBeginImageContextWithOptions(workingImage.size, false, workingImage.scale)
                    defer { UIGraphicsEndImageContext() }

                    guard let context = UIGraphicsGetCurrentContext() else {
                        return
                    }

                    // Draw existing image
                    workingImage.draw(at: .zero)

                    // Configure erasing
                    context.setBlendMode(.clear)
                    context.setStrokeColor(UIColor.black.cgColor)
                    context.setLineWidth(brushSize)
                    context.setLineCap(.round)
                    context.setLineJoin(.round)

                    // Convert points to image coordinates
                    let lastImagePoint = convertViewPointToImagePoint(lastPoint)
                    let currentImagePoint = convertViewPointToImagePoint(currentPoint)

                    // Draw erase line
                    context.move(to: lastImagePoint)
                    context.addLine(to: currentImagePoint)
                    context.strokePath()

                    // Get the new image and update
                    if let newImage = UIGraphicsGetImageFromCurrentImageContext() {
                        workingImage = newImage
                        imageView.image = workingImage
                    }

                    // Update last point
                    self.lastPoint = currentPoint
                }

                override func touchesEnded(_ touches: Set<UITouch>, with event: UIEvent?) {
                    super.touchesEnded(touches, with: event)

                    guard let touch = touches.first else { return }

                    if touch == activeEraseTouch {
                        activeEraseTouch = nil
                        isFingerTouching = false
                        isPenTouching = false
                        touchStarted = false
                        brushIndicator.isHidden = true
                        lastPoint = nil

                        if let delegate = delegate, let imageDidChange = delegate.imageDidChange {
                            imageDidChange(workingImage)
                        }
                    }
                }

                override func touchesCancelled(_ touches: Set<UITouch>, with event: UIEvent?) {
                    super.touchesCancelled(touches, with: event)

                    guard let touch = touches.first else { return }

                    if touch == activeEraseTouch {
                        activeEraseTouch = nil
                        isFingerTouching = false
                        isPenTouching = false
                        touchStarted = false
                        brushIndicator.isHidden = true
                        lastPoint = nil
                    }

                    // Always ensure we unlock the form when touches cancel
                    disableParentGestures(false)
                }

                private func commitTempErase() {
                    guard tempEraseLayer.path != nil else {
                        clearTempEraseLayer()
                        return
                    }

                    UIGraphicsBeginImageContextWithOptions(workingImage.size, false, workingImage.scale)
                    defer { UIGraphicsEndImageContext() }
                    guard let context = UIGraphicsGetCurrentContext() else { return }

                    // Draw the original image
                    workingImage.draw(at: .zero)

                    // Set up for erasing with the path
                    context.setBlendMode(.clear)
                    context.setStrokeColor(UIColor.black.cgColor)
                    context.setLineWidth(brushSize)
                    context.setLineCap(.round)

                    // Add the path to the context and stroke it
                    context.addPath(tempEraseLayer.path!)
                    context.strokePath()

                    // Also add any filled circles we might have created
                    if let erasePath = tempEraseLayer.path {
                        context.addPath(erasePath)
                        context.fillPath()
                    }

                    if let newImage = UIGraphicsGetImageFromCurrentImageContext() {
                        workingImage = newImage
                        imageView.image = workingImage
                        if let delegate = delegate, let imageDidChange = delegate.imageDidChange {
                            imageDidChange(workingImage)
                        }
                    }

                    clearTempEraseLayer()
                }

                private func clearTempEraseLayer() {
                    tempEraseLayer.path = nil
                    tempEraseLayer.fillColor = UIColor.clear.cgColor
                }

                // Helper function to check if any gesture recognizer is active
                private func isGestureRecognizerActive() -> Bool {
                    for gesture in [pinchGesture, panGesture, rotationGesture] {
                        if gesture?.state == .began || gesture?.state == .changed {
                            return true
                        }
                    }
                    return false
                }

                // MARK: - Helper Methods
                private func updateBrushPosition(at point: CGPoint) {
                    let pointInContainer = point
                    let pointInImageView = containerView.convert(pointInContainer, to: self)
                    brushIndicator.center = pointInImageView

                    guard let image = imageView.image else { return }
                    let imageSize = image.size
                    let imageViewSize = imageView.bounds.size
                    let imageAspectRatio = imageSize.width / imageSize.height
                    let imageViewAspectRatio = imageViewSize.width / imageViewSize.height

                    var scaledImageSize: CGSize
                    if imageAspectRatio > imageViewAspectRatio {
                        scaledImageSize = CGSize(width: imageViewSize.width, height: imageViewSize.width / imageAspectRatio)
                    } else {
                        scaledImageSize = CGSize(width: imageViewSize.height * imageAspectRatio, height: imageViewSize.height)
                    }

                    let imageXOffset = (imageViewSize.width - scaledImageSize.width) / 2
                    let imageYOffset = (imageViewSize.height - scaledImageSize.height) / 2
                    let visibleImageFrame = CGRect(x: imageXOffset, y: imageYOffset, width: scaledImageSize.width, height: scaledImageSize.height)
                    let clampedX = max(visibleImageFrame.minX, min(visibleImageFrame.maxX, pointInImageView.x))
                    let clampedY = max(visibleImageFrame.minY, min(visibleImageFrame.maxY, pointInImageView.y))
                    brushIndicator.center = CGPoint(x: clampedX, y: clampedY)
                }

                private func eraseAt(viewPoint: CGPoint) {
                    let imagePoint = convertViewPointToImagePoint(viewPoint)
                    UIGraphicsBeginImageContextWithOptions(workingImage.size, false, workingImage.scale)
                           defer { UIGraphicsEndImageContext() }

                            guard let context = UIGraphicsGetCurrentContext() else { return }

                            // Draw existing image
                            workingImage.draw(at: .zero)

                            // Set up for erasing
                            context.setBlendMode(.clear)
                            context.setFillColor(UIColor.clear.cgColor)

                            // Erase a circle at the point
                            let eraseRect = CGRect(
                                x: imagePoint.x - brushSize/2,
                                y: imagePoint.y - brushSize/2,
                                width: brushSize,
                                height: brushSize
                            )
                            context.fillEllipse(in: eraseRect)

                            // Update the image
                            if let newImage = UIGraphicsGetImageFromCurrentImageContext() {
                                workingImage = newImage
                                imageView.image = workingImage
                            }
                        }

                        private func convertViewPointToImagePoint(_ viewPoint: CGPoint) -> CGPoint {
                            let pointInImageView = containerView.convert(viewPoint, to: imageView)

                            let imageSize = workingImage.size
                            let viewSize = imageView.bounds.size
                            let imageAspect = imageSize.width / imageSize.height
                            let viewAspect = viewSize.width / viewSize.height

                            var imageFrame: CGRect
                            if imageAspect > viewAspect {
                                let height = viewSize.width / imageAspect
                                let yOffset = (viewSize.height - height) / 2
                                imageFrame = CGRect(x: 0, y: yOffset, width: viewSize.width, height: height)
                            } else {
                                let width = viewSize.height * imageAspect
                                let xOffset = (viewSize.width - width) / 2
                                imageFrame = CGRect(x: xOffset, y: 0, width: width, height: viewSize.height)
                            }

                            let scaleX = imageSize.width / imageFrame.width
                            let scaleY = imageSize.height / imageFrame.height

                            let imageX = (pointInImageView.x - imageFrame.origin.x) * scaleX
                            let imageY = (pointInImageView.y - imageFrame.origin.y) * scaleY

                            let finalPoint = CGPoint(x: max(0, min(imageSize.width, imageX)), y: max(0, min(imageSize.height, imageY)))
                            return finalPoint
                        }

                        // MARK: - Image Reset and Gesture Conflict Management
                        func resetImage() {
                            workingImage = originalImage
                            imageView.image = workingImage
                            if let delegate = delegate, let imageDidChange = delegate.imageDidChange {
                                imageDidChange(workingImage)
                            }
                            currentScale = 1.0
                            currentTranslation = .zero
                            currentRotation = 0.0
                            imageView.transform = .identity
                        }

                        // Gesture Conflict Fix
                        private func disableParentGestures(_ disable: Bool) {
                            var view: UIView? = self
                            while let superview = view?.superview {
                                view = superview
                                if let gestureRecognizers = view?.gestureRecognizers {
                                    gestureRecognizers.forEach { $0.isEnabled = !disable }
                                }
                            }
                        }
                    }

                    // MARK: - UIGestureRecognizerDelegate
                    extension UIKitEraser: UIGestureRecognizerDelegate {
                        func gestureRecognizer(_ gestureRecognizer: UIGestureRecognizer, shouldRecognizeSimultaneouslyWith otherGestureRecognizer: UIGestureRecognizer) -> Bool {
                            // Never allow simultaneous recognition with erasing gestures
                            if gestureRecognizer is UITapGestureRecognizer ||
                                otherGestureRecognizer is UITapGestureRecognizer {
                                return false
                            }

                            // Never allow single-finger pan to work with other gestures
                            if (gestureRecognizer is UIPanGestureRecognizer && gestureRecognizer.numberOfTouches == 1) ||
                                (otherGestureRecognizer is UIPanGestureRecognizer && otherGestureRecognizer.numberOfTouches == 1) {
                                return false
                            }

                            // Allow multi-finger manipulation gestures to work together
                            if (gestureRecognizer is UIPinchGestureRecognizer ||
                                gestureRecognizer is UIRotationGestureRecognizer ||
                                (gestureRecognizer is UIPanGestureRecognizer && gestureRecognizer.numberOfTouches > 1)) &&
                                (otherGestureRecognizer is UIPinchGestureRecognizer ||
                                 otherGestureRecognizer is UIRotationGestureRecognizer ||
                                 (otherGestureRecognizer is UIPanGestureRecognizer && otherGestureRecognizer.numberOfTouches > 1)) {
                                return true
                            }

                            return false
                        }

                        override func gestureRecognizerShouldBegin(_ gestureRecognizer: UIGestureRecognizer) -> Bool {
                            // Critical fix: If this is a single-finger pan gesture and we're erasing
                            // Prevent it from recognizing to let touchesBegan/Moved handle it instead
                            if gestureRecognizer is UIPanGestureRecognizer &&
                                gestureRecognizer.numberOfTouches == 1 {
                                return false
                            }

                            return true
                        }
                    }

                    // MARK: - Extension for CGAffineTransform
                    extension CGAffineTransform {
                        var scale: CGFloat {
                            return sqrt(a * a + c * c)
                        }
                    }
