import SwiftUI
import UIKit

struct ImageEraser: View {
    @Environment(\.presentationMode) var presentationMode
    @State private var brushSize: CGFloat = 20.0
    @State private var uiImage: UIImage

    // Completion handler to return the edited image
    var onSave: (UIImage) -> Void

    init(image: UIImage, onSave: @escaping (UIImage) -> Void) {
        _uiImage = State(initialValue: image)
        self.onSave = onSave
    }

    var body: some View {
        NavigationView {
            VStack {
                // Toolbar
                HStack {
                    Text("Eraser Tool").font(.headline)
                    Spacer()
                    HStack {
                        Text("Brush Size:")
                        Slider(value: $brushSize, in: 5...50)
                            .frame(width: 120)
                    }
                }
                .padding()

                // Use UIKit-based eraser view
                UIKitEraserView(image: $uiImage, brushSize: $brushSize)
                    .frame(maxWidth: .infinity, maxHeight: .infinity)
                    .background(Color.white) // White background for proper transparency
                    .cornerRadius(8)
                    .padding(.horizontal)

                Text("One finger to erase, two fingers to pan/zoom")
                    .font(.caption)
                    .foregroundColor(.gray)
                    .padding(.top, 5)
            }
            .padding(.vertical)
            .navigationBarTitle("Erase Image Parts", displayMode: .inline)
            .navigationBarItems(
                leading: Button("Cancel") {
                    presentationMode.wrappedValue.dismiss()
                },
                trailing: Button("Save") {
                    onSave(uiImage)
                    presentationMode.wrappedValue.dismiss()
                }
            )
            // Prevent the swipe to dismiss gesture
            .interactiveDismissDisabled()
        }
    }
}

// UIViewRepresentable wrapper for a UIKit-based eraser
struct UIKitEraserView: UIViewRepresentable {
    @Binding var image: UIImage
    @Binding var brushSize: CGFloat

    func makeUIView(context: Context) -> UIKitEraser {
        let eraser = UIKitEraser(image: image, brushSize: brushSize)
        eraser.delegate = context.coordinator
        return eraser
    }

    func updateUIView(_ uiView: UIKitEraser, context: Context) {
        uiView.brushSize = brushSize
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
protocol UIKitEraserDelegate: AnyObject {
    func imageDidChange(_ newImage: UIImage)
}

// Custom UIKit view for image erasing
class UIKitEraser: UIView {
    // Image properties
    private var originalImage: UIImage
    private var workingImage: UIImage
    private var imageView: UIImageView!
    private var containerView: UIView!
    private var eraseDelayTimer: Timer? // Added from Code B
    private var tempEraseLayer: CAShapeLayer!
    
    // Drawing properties
    var brushSize: CGFloat {
        didSet {
            updateBrushIndicator()
        }
    }
    private var brushIndicator: UIView!
    
    // Gesture state
    private var lastPoint: CGPoint?
    private var touchStarted = false
    
    // Transform state
    private var currentScale: CGFloat = 1.0
    private var currentTranslation: CGPoint = .zero
    private var currentRotation: CGFloat = 0.0
    
    // Delegate
    weak var delegate: UIKitEraserDelegate?
    
    // Initialization
    init(image: UIImage, brushSize: CGFloat) {
        self.originalImage = image
        self.workingImage = image
        self.brushSize = brushSize
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
        let pinchGesture = UIPinchGestureRecognizer(target: self, action: #selector(handlePinch(_:)))
        let panGesture = UIPanGestureRecognizer(target: self, action: #selector(handlePan(_:)))
        let rotationGesture = UIRotationGestureRecognizer(target: self, action: #selector(handleRotation(_:)))
        
        panGesture.minimumNumberOfTouches = 2
        
        pinchGesture.delegate = self
        panGesture.delegate = self
        rotationGesture.delegate = self
        
        containerView.addGestureRecognizer(pinchGesture)
        containerView.addGestureRecognizer(panGesture)
        containerView.addGestureRecognizer(rotationGesture)
        
        self.isMultipleTouchEnabled = true
    }
    
    private func updateBrushIndicator() {
        brushIndicator.frame = CGRect(x: 0, y: 0, width: brushSize, height: brushSize)
        brushIndicator.layer.cornerRadius = brushSize / 2
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
    
    // MARK: - Touch Handling for Erasing (COMBINED FROM CODE A & B)
    
    override func touchesBegan(_ touches: Set<UITouch>, with event: UIEvent?) {
        super.touchesBegan(touches, with: event)

        guard let touch = touches.first else { return }

        if touches.count > 1 {
            touchStarted = false
            brushIndicator.isHidden = true
            clearTempEraseLayer()
            return
        }

        let location = touch.location(in: self.containerView)
        updateBrushPosition(at: location)
        lastPoint = location
        touchStarted = true
        brushIndicator.isHidden = false

        // Start drawing on the temporary layer
        startErasingTemp(at: convertViewPointToImagePoint(location))

        // This is the critical line that locks your form
        disableParentGestures(true)
    }
    
    private func startErasingTemp(at imagePoint: CGPoint) {
        // Create an initial dot path
        let path = UIBezierPath()
        path.move(to: imagePoint)
        path.addLine(to: imagePoint) // This creates a "dot"
        
        tempEraseLayer.path = path.cgPath
        tempEraseLayer.strokeColor = UIColor.clear.cgColor
        tempEraseLayer.lineWidth = brushSize
        tempEraseLayer.lineCap = .round
        tempEraseLayer.fillColor = nil // We're using stroke not fill
    }
    
    override func touchesMoved(_ touches: Set<UITouch>, with event: UIEvent?) {
        super.touchesMoved(touches, with: event)

        if touches.count > 1 || !touchStarted {
            return
        }

        guard let touch = touches.first, let lastPoint = self.lastPoint else { return }
        let currentPoint = touch.location(in: containerView)
        updateBrushPosition(at: currentPoint)
        
        // Convert points to image coordinates
        let lastImagePoint = convertViewPointToImagePoint(lastPoint)
        let currentImagePoint = convertViewPointToImagePoint(currentPoint)
        
        // Apply erasing in real-time
        UIGraphicsBeginImageContextWithOptions(workingImage.size, false, workingImage.scale)
        defer { UIGraphicsEndImageContext() }
        guard let context = UIGraphicsGetCurrentContext() else { return }
        
        // Draw the current image
        workingImage.draw(at: .zero)
        
        // Set up for erasing the current segment
        context.setBlendMode(.clear)
        context.setStrokeColor(UIColor.black.cgColor)
        context.setLineWidth(brushSize)
        context.setLineCap(.round)
        
        // Draw the current segment
        context.move(to: lastImagePoint)
        context.addLine(to: currentImagePoint)
        context.strokePath()
        
        if let newImage = UIGraphicsGetImageFromCurrentImageContext() {
            workingImage = newImage
            imageView.image = workingImage
        }
        
        self.lastPoint = currentPoint
    }
    
    override func touchesEnded(_ touches: Set<UITouch>, with event: UIEvent?) {
        super.touchesEnded(touches, with: event)

        if touchStarted {
            delegate?.imageDidChange(workingImage)
            clearTempEraseLayer()
        }

        touchStarted = false
        brushIndicator.isHidden = true
        lastPoint = nil
        
        // Always ensure we unlock the form at the end
        disableParentGestures(false)
    }
    
    override func touchesCancelled(_ touches: Set<UITouch>, with event: UIEvent?) {
        super.touchesCancelled(touches, with: event)

        eraseDelayTimer?.invalidate()
        touchStarted = false
        brushIndicator.isHidden = true
        lastPoint = nil
        
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
            delegate?.imageDidChange(workingImage)
        }
        
        clearTempEraseLayer()
    }
    
    private func clearTempEraseLayer() {
        tempEraseLayer.path = nil
        tempEraseLayer.fillColor = UIColor.clear.cgColor
    }
    
    // Helper function to check if any gesture recognizer is active
    private func isGestureRecognizerActive() -> Bool {
        for gesture in containerView.gestureRecognizers ?? [] {
            if gesture.state == .began || gesture.state == .changed || gesture.state == .possible {
                // Check if it's a multi-touch gesture
                if let pan = gesture as? UIPanGestureRecognizer, pan.numberOfTouches > 1 {
                    return true
                }
                if let pinch = gesture as? UIPinchGestureRecognizer, pinch.numberOfTouches > 1 {
                    return true
                }
                if let rotate = gesture as? UIRotationGestureRecognizer, rotate.numberOfTouches > 1 {
                    return true
                }
            }
        }
        return false
    }
    
    // MARK: - Helper Methods (Likely Present in Both)
    
    private func updateBrushPosition(at point: CGPoint) {
        let pointInContainer = point
        let pointInImageView = containerView.convert(pointInContainer, to: self)
        brushIndicator.center = pointInImageView
        
        //let pointInImageView = containerView.convert(point, to: imageView)
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
        workingImage.draw(at: .zero)
        context.setBlendMode(.clear)
        context.setFillColor(UIColor.clear.cgColor)
        let eraseRect = CGRect(x: imagePoint.x - brushSize/2, y: imagePoint.y - brushSize/2, width: brushSize, height: brushSize)
        context.fillEllipse(in: eraseRect)
        if let newImage = UIGraphicsGetImageFromCurrentImageContext() {
            workingImage = newImage
            imageView.image = workingImage
            delegate?.imageDidChange(workingImage)
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
        return CGPoint(x: max(0, min(imageSize.width, imageX)), y: max(0, min(imageSize.height, imageY)))
    }
    
    func resetImage() {
        workingImage = originalImage
        imageView.image = workingImage
        delegate?.imageDidChange(workingImage)
        currentScale = 1.0
        currentTranslation = .zero
        currentRotation = 0.0
        imageView.transform = .identity
    }
    
    // Gesture Conflict Fix (Likely Present in Both)
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

// MARK: - UIGestureRecognizerDelegate (REPLACED WITH MORE SPECIFIC VERSION)

extension UIKitEraser: UIGestureRecognizerDelegate {
    func gestureRecognizer(_ gestureRecognizer: UIGestureRecognizer, shouldRecognizeSimultaneouslyWith otherGestureRecognizer: UIGestureRecognizer) -> Bool {
        if (gestureRecognizer is UIPinchGestureRecognizer || gestureRecognizer is UIRotationGestureRecognizer || gestureRecognizer is UIPanGestureRecognizer) {
            return true
        }
        return false
    }

    override func gestureRecognizerShouldBegin(_ gestureRecognizer: UIGestureRecognizer) -> Bool {
        // If a two-finger gesture is starting, clear the temporary erase layer
        if (gestureRecognizer is UIPanGestureRecognizer && gestureRecognizer.numberOfTouches == 2) ||
           (gestureRecognizer is UIPinchGestureRecognizer && gestureRecognizer.numberOfTouches == 2) ||
           (gestureRecognizer is UIRotationGestureRecognizer && gestureRecognizer.numberOfTouches == 2) {
            clearTempEraseLayer()
            return true
        }

        // Prevent single-finger pan from interfering
        if let pan = gestureRecognizer as? UIPanGestureRecognizer, pan.numberOfTouches == 1 {
            return false
        }
        // Prevent single-finger pinch/rotate (though unlikely with min touches set)
        if let pinch = gestureRecognizer as? UIPinchGestureRecognizer, pinch.numberOfTouches == 1 {
            return false
        }
        if let rotate = gestureRecognizer as? UIRotationGestureRecognizer, rotate.numberOfTouches == 1 {
            return false
        }
        return true
    }
}
// MARK: - Extension for CGAffineTransform (Likely Present in Both)

extension CGAffineTransform {
    var scale: CGFloat {
        return sqrt(a * a + c * c)
    }
}
