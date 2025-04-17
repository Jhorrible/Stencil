import SwiftUI
import UIKit
import AVFoundation // Make sure this import is present

struct ImageEraser: View {
    @Environment(\.presentationMode) var presentationMode
    @State private var brushSize: CGFloat = 20.0
    @State private var uiImage: UIImage
    @State private var isCropping: Bool = false
    @State private var cropRect: CGRect?
    @GestureState private var dragOffset = CGSize.zero
    @State private var initialCropRect: CGRect?
    @State private var croppedImage: UIImage? // To hold the cropped image before saving
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
                    UIKitEraserView(isCropping: $isCropping, cropRect: $cropRect, image: $uiImage, brushSize: $brushSize, imageFrame: $imageFrame)
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

                            print("SwiftUI: geometry.size = \(geometry.size), imageFrame = \(imageFrame)")
                        }
                        .gesture(
                            DragGesture(minimumDistance: 0)
                                .updating($dragOffset) { drag, state, transaction in
                                    if isCropping {
                                        state = drag.translation
                                    }
                                }
                                .onChanged { value in
                                    if isCropping {
                                        if initialCropRect == nil {
                                            initialCropRect = CGRect(origin: value.startLocation, size: .zero)
                                        }
                                        let minX = min(value.startLocation.x, value.location.x)
                                        let minY = min(value.startLocation.y, value.location.y)
                                        let maxX = max(value.startLocation.x, value.location.x)
                                        let maxY = max(value.startLocation.y, value.location.y)
                                        cropRect = CGRect(x: minX, y: minY, width: maxX - minX, height: maxY - minY)
                                    }
                                }
                                .onEnded { _ in
                                    initialCropRect = nil
                                }
                        )
                }
                .frame(height: UIScreen.main.bounds.height * 0.6)
                .padding(.horizontal, 8)

                // Tools container - now with auto-sizing height
                VStack(alignment: .center, spacing: 15) {
                    Spacer().frame(height: 15) // Top spacing

                    // Tools
                    VStack(spacing: 12) { // Group tools with spacing
                        Button(action: {
                            isCropping.toggle()
                            cropRect = nil // Reset crop rect when toggling
                        }) {
                            Image(systemName: "crop")
                                .font(.system(size: 20))
                                .foregroundColor(isCropping ? .blue : .gray)
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
                    VStack(spacing: 12) { // Group buttons
                        Button(action: {
                            // Trigger cropping in UIKitEraser and then save
                            if let currentCrop = cropRect {
                                croppedImage = UIKitEraser.crop(image: uiImage, to: convertToImageCoordinates(viewRect: currentCrop))
                                if let finalImage = croppedImage {
                                    onSave(finalImage)
                                    presentationMode.wrappedValue.dismiss()
                                }
                            } else {
                                // If not cropping, save the current state (erased image)
                                onSave(uiImage)
                                presentationMode.wrappedValue.dismiss()
                            }
                        }) {
                            Image(systemName: "arrow.down.circle") // Different Save icon
                                .font(.system(size: 20))
                                .foregroundColor(.black)
                                .frame(width: 40, height: 40)
                                .background(Color(UIColor.systemBackground))
                                .cornerRadius(8)
                        }

                        Button(action: {
                            isCropping = false
                            cropRect = nil
                            // Optionally reset any changes made in UIKitEraser if needed
                        }) {
                            Image(systemName: "x.circle") // Different Cancel icon
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
                // Remove the .frame(maxHeight: .infinity) to let it size to content
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

            // Crop overlay if needed
            if isCropping, let currentCropRect = cropRect {
                GeometryReader { geometry in
                    let imageContainerWidth = geometry.size.width - 60 - 16 // Account for toolbar and padding
                    let imageContainerHeight = UIScreen.main.bounds.height * 0.6
                    let scaleX = imageContainerWidth / uiImage.size.width
                    let scaleY = imageContainerHeight / uiImage.size.height
                    let scale = min(scaleX, scaleY)

                    let scaledWidth = uiImage.size.width * scale
                    let scaledHeight = uiImage.size.height * scale

                    let offsetX = (imageContainerWidth - scaledWidth) / 2 + 8 // Account for leading padding
                    let offsetY = (imageContainerHeight - scaledHeight) / 2

                    let normalizedCropRect = CGRect(
                        x: currentCropRect.minX / imageContainerWidth * scaledWidth + offsetX,
                        y: currentCropRect.minY / imageContainerHeight * scaledHeight + offsetY,
                        width: currentCropRect.width / imageContainerWidth * scaledWidth,
                        height: currentCropRect.height / imageContainerHeight * scaledHeight
                    )

                    Rectangle()
                        .stroke(Color.blue, lineWidth: 2)
                        .frame(width: normalizedCropRect.width, height: normalizedCropRect.height)
                        .position(x: normalizedCropRect.midX, y: normalizedCropRect.midY)
                }
                .allowsHitTesting(false)
            }
        }
        .edgesIgnoringSafeArea(.all)
        .navigationBarHidden(true)
    }

    private func convertToImageCoordinates(viewRect: CGRect) -> CGRect {
        // Calculate the position of the image within the UIKitEraserView
        guard let imageSize = UIKitEraser.getImageSize(from: uiImage), imageSize.width > 0, imageSize.height > 0 else {
            return .zero // Or handle the error appropriately
        }

        let viewWidth = UIScreen.main.bounds.width - 60 - 16 // Adjusted for toolbar and padding
        let viewHeight = UIScreen.main.bounds.height * 0.6

        let imageAspect = imageSize.width / imageSize.height
        let viewAspect = viewWidth / viewHeight

        var scaledImageFrame = CGRect.zero

        if imageAspect > viewAspect {
            scaledImageFrame = CGRect(x: 0, y: (viewHeight - viewWidth / imageAspect) / 2, width: viewWidth, height: viewWidth / imageAspect)
        } else {
            scaledImageFrame = CGRect(x: (viewWidth - viewHeight * imageAspect) / 2, y: 0, width: viewHeight * imageAspect, height: viewHeight)
        }

        // Calculate the scale factors
        let scaleX = imageSize.width / scaledImageFrame.width
        let scaleY = imageSize.height / scaledImageFrame.height

        // Calculate the offset of the image within the UIKitEraserView
        let offsetX = scaledImageFrame.minX
        let offsetY = scaledImageFrame.minY

        // Convert the viewRect to image coordinates
        let imageX = (viewRect.minX - offsetX) / scaleX
        let imageY = (viewRect.minY - offsetY) / scaleY
        let imageWidth = viewRect.width / scaleX
        let imageHeight = viewRect.height / scaleY

        return CGRect(x: imageX, y: imageY, width: imageWidth, height: imageHeight)
    }
}

// UIViewRepresentable wrapper for a UIKit-based eraser
struct UIKitEraserView: UIViewRepresentable {
    @Binding var isCropping: Bool
    @Binding var cropRect: CGRect?
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
        uiView.isCropping = isCropping
        uiView.currentCropRect = cropRect // Pass the crop rect to UIKitEraser
        uiView.imageFrame = imageFrame // Update the image frame in UIKitEraser

        // No longer directly cropping here based on state changes.
        // Cropping will be triggered by the Save button action in SwiftUI.

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

    // MARK: - Cropping Properties

    var isCropping: Bool = false {
        didSet {
            if isCropping {
                setupCropOverlay()
                // Disable image manipulation gestures when cropping
                pinchGesture.isEnabled = false
                panGesture.isEnabled = false
                rotationGesture.isEnabled = false
            } else {
                removeCropOverlay()
                // Enable image manipulation gestures when not cropping
                pinchGesture.isEnabled = true
                panGesture.isEnabled = true
                rotationGesture.isEnabled = true
            }
        }
    }

    var currentCropRect: CGRect? {
        didSet {
            updateCropOverlay() // Update the overlay when the rect changes
        }
    }

    private var cropOverlayView: UIView?
    private var cropPanGesture: UIPanGestureRecognizer?
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
        tempEraseLayer.strokeColor = UIColor.clear.cgColor // Initially transparent
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

    // MARK: - Cropping Methods
    private func calculateImageFrame() -> CGRect {
        return imageFrame // Use the frame passed from SwiftUI
    }

    private func setupCropOverlay() {
        // Clear any existing overlay
        removeCropOverlay()

        cropOverlayView = UIView()
        cropOverlayView?.backgroundColor = UIColor.black.withAlphaComponent(0.5)
        cropOverlayView?.frame = bounds

        // Add crop overlay to view hierarchy
        if let overlay = cropOverlayView {
            addSubview(overlay)
        }

        // Initial crop rect (centered at 50% of the image)
        let imageFrame = calculateImageFrame()
        currentCropRect = CGRect(
            x: imageFrame.minX + imageFrame.width * 0.25,
            y: imageFrame.minY + imageFrame.height * 0.25,
            width: imageFrame.width * 0.5,
            height: imageFrame.height * 0.5
        )

        updateCropOverlay()

        // Add pan gesture for moving the crop rect
        let panGesture = UIPanGestureRecognizer(target: self, action: #selector(handleCropPan(_:)))
        cropOverlayView?.addGestureRecognizer(panGesture)
    }

    private func updateCropOverlay() {
        guard let cropRect = currentCropRect, let overlay = cropOverlayView else { return }

        // Clear any existing layers
        overlay.layer.sublayers?.removeAll()

        // Create mask path (everything outside crop rect)
        let path = UIBezierPath(rect: bounds)
        path.append(UIBezierPath(rect: cropRect).reversing())

        let maskLayer = CAShapeLayer()
        maskLayer.path = path.cgPath
        maskLayer.fillColor = UIColor.black.withAlphaComponent(0.5).cgColor
        overlay.layer.addSublayer(maskLayer)

        // Add border for crop rect
        let borderLayer = CAShapeLayer()
        borderLayer.path = UIBezierPath(rect: cropRect).cgPath
        borderLayer.fillColor = UIColor.clear.cgColor
        borderLayer.strokeColor = UIColor.white.cgColor
        borderLayer.lineWidth = 2
        overlay.layer.addSublayer(borderLayer)
    }

    private func removeCropOverlay() {
        cropOverlayView?.removeFromSuperview()
        cropOverlayView = nil
    }

    @objc private func handleCropPan(_ gesture: UIPanGestureRecognizer) {
        guard let cropRect = currentCropRect else { return }

        let translation = gesture.translation(in: self)

        if gesture.state == .began || gesture.state == .changed {
            currentCropRect = cropRect.offsetBy(dx: translation.x, dy: translation.y)
            updateCropOverlay()
            gesture.setTranslation(.zero, in: self)
        }
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
        print("UIKit: imageView.bounds = \(imageView.bounds)") // ADD THIS LINE
    }

    // MARK: - Touch Handling for Erasing

    override func touchesBegan(_ touches: Set<UITouch>, with event: UIEvent?) {
        super.touchesBegan(touches, with: event)

        if isCropping || isGestureRecognizerActive() {
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
        
        // Skip if we're not in erase mode or cropping
        if isCropping || !touchStarted {
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
        print("convertViewPointToImagePoint: Input viewPoint = \(viewPoint)")

        let pointInImageView = containerView.convert(viewPoint, to: imageView)
        print("convertViewPointToImagePoint: pointInImageView = \(pointInImageView)")

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
        print("convertViewPointToImagePoint: imageFrame = \(imageFrame)")

        let scaleX = imageSize.width / imageFrame.width
        let scaleY = imageSize.height / imageFrame.height
        print("convertViewPointToImagePoint: scaleX = \(scaleX), scaleY = \(scaleY)")

        let imageX = (pointInImageView.x - imageFrame.origin.x) * scaleX
        let imageY = (pointInImageView.y - imageFrame.origin.y) * scaleY
        print("convertViewPointToImagePoint: Pre-clamped imageX = \(imageX), imageY = \(imageY)")

        let finalPoint = CGPoint(x: max(0, min(imageSize.width, imageX)), y: max(0, min(imageSize.height, imageY)))
        print("convertViewPointToImagePoint: Output finalPoint = \(finalPoint)")

        return finalPoint
    }

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

    // MARK: - Image Cropping Logic

    // Static function to perform the cropping
    static func crop(image: UIImage, to rect: CGRect) -> UIImage? {
        guard let cgImage = image.cgImage?.cropping(to: rect) else { return nil }
        return UIImage(cgImage: cgImage, scale: image.scale, orientation: image.imageOrientation)
    }

    static func getImageSize(from image: UIImage) -> CGSize? {
        guard let cgImage = image.cgImage else {
            return nil
        }
        return CGSize(width: cgImage.width, height: cgImage.height)
    }

    private func convertToImageCoordinates(_ viewRect: CGRect) -> CGRect {
        // This function is no longer used here.
        // The coordinate conversion is now handled in SwiftUI's convertToImageCoordinates.
        return .zero
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
        // If we're in crop mode
        if isCropping {
            // Disable image manipulation gestures
            if gestureRecognizer == pinchGesture ||
                gestureRecognizer == panGesture ||
                gestureRecognizer == rotationGesture {
                return false
            }
            return true
        }
        
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
