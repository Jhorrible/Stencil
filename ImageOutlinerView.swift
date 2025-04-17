// ImageOutlinerView.swift
import SwiftUI
import UIKit
import CoreImage
import CoreImage.CIFilterBuiltins
import Photos
import UniformTypeIdentifiers

struct ImageOutlinerView: View {
    @Binding var inputImage: UIImage?
    @State private var isMenuVisible: Bool = false
    @State private var processedImage: UIImage?
    @State private var showImagePicker = false
    @State private var brightness: Float = 0.0
    @State private var contrast: Float = 1.0
    @State private var curves: Float = 1.0
    @State private var lineBoldness: Float = 1.0
    @State private var currentScale: CGFloat = 1.0
    @State private var lastScale: CGFloat = 1.0
    @State private var offset: CGSize = .zero
    @State private var lastOffset: CGSize = .zero
    @State private var rotationAngle: Double = 0.0
    @State private var flipHorizontal: Bool = false
    @State private var flipVertical: Bool = false
    @State private var image: UIImage?
    @State private var isPickerPresented = false
    @State private var showingSaveOptions = false
    @State private var isDocumentPickerPresented = false
    @State private var imageToExport: UIImage?
    @State private var showSaveConfirmation = false
    @State private var showInfoMode = false
    @State private var showImageEraser = false
    @State private var isEraserActive = false
    @State private var isGrayscaleEnabled = false

    @Environment(\.horizontalSizeClass) private var horizontalSizeClass
    @Environment(\.verticalSizeClass) private var verticalSizeClass

    let context = CIContext()

    var isLandscape: Bool {
        return horizontalSizeClass == .regular && verticalSizeClass == .compact
    }

    var body: some View {
        GeometryReader { screenGeo in
            ZStack {
                // Menu Bar
                VStack {
                    AppMenuBarContainer(
                        onEraserTapped: { showImageEraser = true },
                        onSettingsTapped: { /* Handle settings */ },
                        onExitTapped: { /* Handle exit */ },
                        onAboutTapped: { /* Handle about */ },
                        onFAATapped: { /* Handle Filters & Adjustments */ }
                    )
                    .frame(height: 44)
                    .background(Color(.systemGray).opacity(0.8))
                    .zIndex(1)
                    Spacer()
                }

                // Main Content
                if showImageEraser, let imageToEdit = processedImage ?? inputImage {
                    ImageEraser(image: imageToEdit) { editedImage in
                        inputImage = editedImage
                        showImageEraser = false
                        updateProcessedImage() // Use updateProcessedImage
                    }
                    .edgesIgnoringSafeArea(.all)
                    .transition(.move(edge: .bottom))
                    .zIndex(10)
                } else {
                    if isLandscape {
                        landscapeLayout(screenSize: screenGeo.size)
                    } else {
                        portraitLayout(screenSize: screenGeo.size)
                    }
                }

                // Save Confirmation Pop-up
                if showSaveConfirmation {
                    Text("Image saved to Photos")
                        .padding()
                        .background(Color.green.opacity(0.8))
                        .foregroundColor(.white)
                        .cornerRadius(10)
                        .transition(.opacity.animation(.easeInOut(duration: 0.5)))
                        .onAppear {
                            DispatchQueue.main.asyncAfter(deadline: .now() + 1.5) {
                                withAnimation { showSaveConfirmation = false }
                            }
                        }
                }
            }
            .frame(width: screenGeo.size.width, height: screenGeo.size.height)
            .onTapGesture { /* Dismiss dropdowns */ }
            .sheet(isPresented: $showImagePicker) {
                ImagePicker(image: $inputImage) {
                    if let _ = inputImage {
                        updateProcessedImage() // Use updateProcessedImage
                    }
                }
            }
        }
    }

    // MARK: - Image Display

    func imageDisplayView(width: CGFloat, height: CGFloat) -> some View {
        ZStack {
            VStack(spacing: 0) {
                if let processedImage = processedImage {
                    Image(uiImage: processedImage)
                        .resizable()
                        .scaledToFit()
                        .scaleEffect(currentScale)
                        .offset(offset)
                        .gesture(
                            MagnificationGesture()
                                .onChanged { value in currentScale = lastScale * value }
                                .onEnded { _ in lastScale = currentScale }
                        )
                        .gesture(
                            DragGesture()
                                .onChanged { value in
                                    offset = CGSize(width: lastOffset.width + value.translation.width,
                                                    height: lastOffset.height + value.translation.height)
                                }
                                .onEnded { _ in lastOffset = offset }
                        )
                } else if let inputImage = inputImage {
                    Image(uiImage: inputImage)
                        .resizable()
                        .scaledToFit()
                        .scaleEffect(currentScale)
                        .offset(offset)
                        .gesture(
                            MagnificationGesture()
                                .onChanged { value in currentScale = lastScale * value }
                                .onEnded { _ in lastScale = currentScale }
                        )
                        .gesture(
                            DragGesture()
                                .onChanged { value in
                                    offset = CGSize(width: lastOffset.width + value.translation.width,
                                                    height: lastOffset.height + value.translation.height)
                                }
                                .onEnded { _ in lastOffset = offset }
                        )
                } else {
                    Text("Select an image to begin").foregroundColor(.gray)
                }
            }
            .frame(width: width, height: height)
            .background(Color.white)
            .clipped()
            .cornerRadius(8)
        }
    }

    // MARK: - Layout Functions

    func landscapeLayout(screenSize: CGSize) -> some View {
        GeometryReader { geo in
            VStack(spacing: 0) {
                // Menu Bar
                AppMenuBarContainer(
                    onEraserTapped: { showImageEraser = true },
                    onSettingsTapped: { /* Handle settings */ },
                    onExitTapped: { /* Handle exit */ },
                    onAboutTapped: { /* Handle about */ },
                    onFAATapped: { /* Handle Filters & Adjustments */ }
                )
                .frame(height: 44)
                .background(Color(.systemGray).opacity(0.8))
                .zIndex(1)

                HStack(spacing: 0) {
                    ZStack(alignment: .topTrailing) {
                        imageDisplayView(width: geo.size.width * 0.98, height: geo.size.height * 0.9)
                            .padding(.leading, 10)
                            .frame(width: geo.size.width, height: geo.size.height * 0.9)
                    }

                    VStack(spacing: 15) {
                        infoModeToggleButton(iconSize: geo.size.width * 0.02)
                        zoomControls(iconSize: geo.size.width * 0.02)
                        rotationControls(iconSize: geo.size.width * 0.02)
                        flipControls(iconSize: geo.size.width * 0.02)
                        eraserButton(iconSize: geo.size.width * 0.02)
                    }
                    .padding([.top, .trailing], 10)
                }
                .frame(width: geo.size.width, height: geo.size.height)
                .background(Color.black.opacity(0.05))
            }
        }
    }

    func portraitLayout(screenSize: CGSize) -> some View {
        GeometryReader { geo in
            ScrollView {
                VStack(spacing: 10) {
                    // Menu Bar
                    AppMenuBarContainer(
                        onEraserTapped: { showImageEraser = true },
                        onSettingsTapped: { /* Handle settings */ },
                        onExitTapped: { /* Handle exit */ },
                        onAboutTapped: { /* Handle about */ },
                        onFAATapped: { /* Handle Filters & Adjustments */ }
                    )
                    .frame(height: 44)
                    .background(Color(.systemGray).opacity(0.8))
                    .zIndex(1)

                    ZStack(alignment: .topTrailing) {
                        imageDisplayView(width: geo.size.width * 0.98, height: geo.size.height * 0.5)
                            .frame(height: geo.size.height * 0.5)
                            .padding(.horizontal, 10)

                        VStack(spacing: 10) {
                            infoModeToggleButton(iconSize: geo.size.width * 0.03)
                            zoomControls(iconSize: geo.size.width * 0.03)
                            rotationControls(iconSize: geo.size.width * 0.03)
                            flipControls(iconSize: geo.size.width * 0.03)
                            eraserButton(iconSize: geo.size.width * 0.03)
                        }
                        .padding(.top, 10)
                        .padding(.trailing, 10)
                    }

                    VStack(spacing: 10) {
                        adjustmentSliders()
                            .padding(.horizontal, 15)
                        actionButtonsSingleLine()
                            .padding(.horizontal, 15)
                        filterButtons()
                            .padding(.horizontal, 15)
                    }
                    .padding(.bottom, 20)
                }
            }
        }
    }

    // MARK: - UI Control Functions

    func infoModeToggleButton(iconSize: CGFloat) -> some View {
        Button(action: { showInfoMode.toggle() }) {
            Image(systemName: "info.circle")
                .resizable()
                .scaledToFit()
                .frame(width: iconSize, height: iconSize)
                .foregroundColor(showInfoMode ? .blue : .gray)
        }
    }

    func zoomControls(iconSize: CGFloat) -> some View {
        VStack(spacing: 10) {
            iconWithInfoLabel(
                iconName: "minus.magnifyingglass",
                action: {
                    currentScale -= 0.1
                    if currentScale < 0.1 { currentScale = 0.1 }
                },
                labelText: "Zoom Out",
                iconSize: iconSize,
                showInfoMode: showInfoMode
            )
            iconWithInfoLabel(
                iconName: "plus.magnifyingglass",
                action: { currentScale += 0.1 },
                labelText: "Zoom In",
                iconSize: iconSize,
                showInfoMode: showInfoMode
            )
        }
    }

    func rotationControls(iconSize: CGFloat) -> some View {
        VStack(spacing: 10) {
            iconWithInfoLabel(
                iconName: "rotate.right.fill",
                action: {
                    rotationAngle -= 90
                    updateProcessedImage() // Use updateProcessedImage
                },
                labelText: "Rotate Right",
                iconSize: iconSize,
                showInfoMode: showInfoMode
            )
            iconWithInfoLabel(
                iconName: "rotate.left.fill",
                action: {
                    rotationAngle += 90
                    updateProcessedImage() // Use updateProcessedImage
                },
                labelText: "Rotate Left",
                iconSize: iconSize,
                showInfoMode: showInfoMode
            )
        }
    }

    func flipControls(iconSize: CGFloat) -> some View {
        VStack(spacing: 10) {
            iconWithInfoLabel(
                iconName: "flip.horizontal.fill",
                action: {
                    flipHorizontal.toggle()
                    updateProcessedImage() // Use updateProcessedImage
                },
                labelText: "Flip Horizontal",
                iconSize: iconSize,
                showInfoMode: showInfoMode
            )
            iconWithInfoLabel(
                iconName: "arrow.up.arrow.down",
                action: {
                    flipVertical.toggle()
                    updateProcessedImage() // Use updateProcessedImage
                },
                labelText: "Flip Vertical",
                iconSize: iconSize,
                showInfoMode: showInfoMode
            )
        }
    }

    func eraserButton(iconSize: CGFloat) -> some View {
        iconWithInfoLabel(
            iconName: "eraser",
            action: { showImageEraser = true },
            labelText: "Eraser Tool",
            iconSize: iconSize,
            showInfoMode: showInfoMode
        )
    }

    func actionButtonsSingleLine() -> some View {
        HStack(spacing: 10) {
            Button("Choose Image") {
                showImagePicker = true
                resetTransformations()
            }
            .buttonStyle(SmallPrimaryButtonStyle())
            .overlay(
                InfoLabel(text: "Select photo from library",
                          color: Color.white.opacity(0.9),
                          side: .top,
                          width: 120,
                          showInfoMode: showInfoMode)
            )

            Button("Update Image") {
                if let processed = processedImage {
                    inputImage = processed
                    brightness = 0.0
                    contrast = 1.0
                    curves = 1.0
                    lineBoldness = 1.0
                    updateProcessedImage() // Use updateProcessedImage
                }
            }
            .buttonStyle(SmallPrimaryButtonStyle())
            .overlay(
                InfoLabel(text: "Update image to reapply effects",
                          color: Color.white.opacity(0.9),
                          side: .top,
                          width: 120,
                          showInfoMode: showInfoMode)
            )

            Button("Save Image") { showingSaveOptions = true }
                .buttonStyle(SaveButtonStyle())
                .confirmationDialog("Save Image", isPresented: $showingSaveOptions) {
                    Button("Save to Photos", action: saveToPhotosWithConfirmation)
                    Button("Save to Files", action: saveToFiles)
                    Button("Cancel", role: .cancel) { }
                }
                .sheet(isPresented: $isDocumentPickerPresented) {
                    DocumentPicker(image: $imageToExport)
                }
                .overlay(
                    InfoLabel(text: "Save to Photos or Files",
                              color: Color.white.opacity(0.9),
                              side: .top,
                              width: 120,
                              showInfoMode: showInfoMode)
                )

            Button("Print Image") { /* placeholder for print image */ }
                .buttonStyle(PrintButtonStyle())
                .overlay(
                    InfoLabel(text: "Print final image",
                              color: Color.white.opacity(0.9),
                              side: .top,
                              width: 120,
                              showInfoMode: showInfoMode)
                )

            // Grayscale Toggle
            Toggle(isOn: $isGrayscaleEnabled) {
                Text("Grayscale").foregroundColor(.primary)
            }
            .overlay(
                InfoLabel(text: "Convert image to grayscale",
                          color: Color.white.opacity(0.9),
                          side: .top,
                          width: 120,
                          showInfoMode: showInfoMode)
            )
            .onChange(of: isGrayscaleEnabled) { _ in updateProcessedImage() } // Use updateProcessedImage
        }
    }

    func adjustmentSliders() -> some View {
        VStack(spacing: 12) {
            sliderWithValue(label: "Brightness", value: $brightness, range: -1...1, showInfoMode: showInfoMode)
            sliderWithValue(label: "Contrast", value: $contrast, range: 0.5...2.0, showInfoMode: showInfoMode)
            sliderWithValue(label: "Curves", value: $curves, range: 0.0...2.0, showInfoMode: showInfoMode)
            sliderWithValue(label: "Line Boldness", value: $lineBoldness, range: 0.5...3.0, showInfoMode: showInfoMode)
        }
    }

    func filterButtons() -> some View {
        HStack(spacing: 10) {
            Button("Filter 1") {
                brightness = 0.81
                contrast = 2.0
                curves = 2.0
                lineBoldness = 1.0
                updateProcessedImage() // Use updateProcessedImage
                DispatchQueue.main.asyncAfter(deadline: .now() + 0.1) {
                    inputImage = processedImage
                    brightness = -0.11
                    contrast = 1.8
                    curves = 2.0
                    updateProcessedImage() // Use updateProcessedImage
                }
            }
            .buttonStyle(FilterButtonStyle())
            .overlay(
                InfoLabel(text: "Best for stencils on skin",
                          color: Color.white.opacity(0.9),
                          side: .top,
                          width: 120,
                          showInfoMode: showInfoMode)
            )

            Button("Filter 2") {
                brightness = 0.53
                contrast = 2.0
                curves = 1.15
                lineBoldness = 1.0
                updateProcessedImage() // Use updateProcessedImage
            }
            .buttonStyle(FilterButtonStyle())
            .overlay(
                InfoLabel(text: "For nearly complete stencils",
                          color: Color.white.opacity(0.9),
                          side: .top,
                          width: 120,
                          showInfoMode: showInfoMode)
            )

            Button("Filter 3") {
                brightness = 0.2
                contrast = 2.5
                curves = 1.8
                lineBoldness = 2.0
                updateProcessedImage() // Use updateProcessedImage
            }
            .buttonStyle(FilterButtonStyle())
            .overlay(
                InfoLabel(text: "For bold design edges",
                          color: Color.white.opacity(0.9),
                          side: .top,
                          width: 120,
                          showInfoMode: showInfoMode)
            )

            Spacer()
        }
    }

    func saveToPhotosWithConfirmation() {
        guard let finalImageToSave = processedImage ?? inputImage else {
            print("No image available to save.")
            return
        }
        saveImageToPhotosLibrary(finalImageToSave)
        withAnimation { showSaveConfirmation = true }
    }

    func saveToFiles() {
        imageToExport = processedImage ?? inputImage
        isDocumentPickerPresented = true
    }

    func saveImageToPhotosLibrary(_ image: UIImage) {
        PHPhotoLibrary.requestAuthorization { status in
            DispatchQueue.main.async {
                if status == .authorized {
                    UIImageWriteToSavedPhotosAlbum(image, nil, nil, nil)
                    print("Image saved to Photos library.")
                } else {
                    print("Photo library access not authorized.")
                }
            }
        }
    }

    // MARK: - Image Processing

    // Apply content filters only
    func applyContentFilters() {
        guard let inputImage = inputImage,
              let cgImage = inputImage.cgImage else { return }

        let ciImage = CIImage(cgImage: cgImage)
        var output = ciImage

        // Apply grayscale
        if isGrayscaleEnabled {
            let desaturationFilter = CIFilter.colorControls()
            desaturationFilter.inputImage = ciImage
            desaturationFilter.saturation = 0.0
            if let grayImage = desaturationFilter.outputImage {
                output = grayImage
            }
        }

        // Apply filter adjustments
        let adjustFilter = CIFilter.colorControls()
        adjustFilter.inputImage = output
        adjustFilter.brightness = brightness
        adjustFilter.contrast = contrast
        if let adjustedImage = adjustFilter.outputImage {
            output = adjustedImage
        }

        let curvesFilter = CIFilter.colorControls()
        curvesFilter.inputImage = output
        curvesFilter.contrast = curves
        if let curvesOutput = curvesFilter.outputImage {
            output = curvesOutput
        }

        // Apply line boldness
        if lineBoldness > 1.0 {
            if let dilateFilter = CIFilter(name: "CIMorphologyMaximum") {
                dilateFilter.setValue(output, forKey: kCIInputImageKey)
                dilateFilter.setValue(lineBoldness * 2, forKey: "inputRadius")
                if let dilatedOutput = dilateFilter.outputImage {
                    output = dilatedOutput
                }
            }
        }

        if let cgimg = context.createCGImage(output, from: output.extent) {
            processedImage = UIImage(cgImage: cgimg)
        }
    }

    // Apply geometry transformations only
    func applyGeometryTransformations(to image: UIImage?) -> UIImage? {
        guard let image = image, let cgImage = image.cgImage else { return nil }
        let ciImage = CIImage(cgImage: cgImage)
        var currentTransform = CGAffineTransform.identity

        if rotationAngle != 0 {
            currentTransform = currentTransform.rotated(by: CGFloat(rotationAngle * .pi / 180))
        }
        if flipHorizontal {
            currentTransform = currentTransform.scaledBy(x: -1, y: 1)
        }
        if flipVertical {
            currentTransform = currentTransform.concatenating(CGAffineTransform(scaleX: 1, y: -1))
        }

        let transformedImage = ciImage.transformed(by: currentTransform)

        if let cgimg = context.createCGImage(transformedImage, from: transformedImage.extent) {
            return UIImage(cgImage: cgimg)
        }
        return nil
    }

    // Combine content filters and geometry transformations
    func updateProcessedImage() {
        guard let inputImage = inputImage else { return }
        processedImage = applyGeometryTransformations(to: inputImage)
        if processedImage != nil {
            applyContentFilters()
        }
    }

    func resetTransformations() {
        currentScale = 1.0
        lastScale = 1.0
        offset = .zero
        lastOffset = .zero
        rotationAngle = 0.0
        flipHorizontal = false
        flipVertical = false
        // Consider: Reset filter adjustments here as well?
    }

    func sliderWithValue(label: String, value: Binding<Float>, range: ClosedRange<Float>, showInfoMode: Bool) -> some View {
        VStack {
            HStack {
                Text("\(label): \(String(format: "%.2f", value.wrappedValue))")
                    .overlay(alignment: .trailing) {
                        InfoLabel(
                            text: label == "Brightness" ? "Adjust light/dark balance" :
                                label == "Contrast" ? "Modify difference between lights/darks" :
                                label == "Line Boldness" ? "Increase thickness of lines" :
                                "Control tonal range",
                            color: Color.white.opacity(0.9),
                            side: .trailing,
                            width: 120,
                            showInfoMode: showInfoMode
                        )
                        .offset(x: 30, y: -20)
                    }
                Spacer()
            }
            Slider(value: value, in: range)
                .onChange(of: value.wrappedValue) { _ in updateProcessedImage() } // Call updateProcessedImage
                .contentShape(Rectangle())
        }
    }
}

// MARK: - Button Styles

struct EraseButtonStyle: ButtonStyle {
    func makeBody(configuration: Configuration) -> some View {
        configuration.label
            .padding(.horizontal, 20)
            .padding(.vertical, 10)
            .background(Color.purple)
            .foregroundColor(.white)
            .cornerRadius(8)
            .scaleEffect(configuration.isPressed ? 0.95 : 1.0)
            .animation(.easeOut(duration: 0.2), value: configuration.isPressed)
    }
}

struct PrimaryButtonStyle: ButtonStyle {
    func makeBody(configuration: Configuration) -> some View {
        configuration.label
            .frame(maxWidth: .infinity)
            .padding()
            .background(Color.blue)
            .foregroundColor(.white)
            .cornerRadius(10)
            .scaleEffect(configuration.isPressed ? 0.96 : 1.0)
            .animation(.easeOut(duration: 0.2), value: configuration.isPressed)
    }
}

struct SecondaryButtonStyle: ButtonStyle {
    func makeBody(configuration: Configuration) -> some View {
        configuration.label
            .frame(maxWidth: .infinity)
            .padding()
            .background(Color.gray.opacity(0.5))
            .foregroundColor(.white)
            .cornerRadius(10)
            .scaleEffect(configuration.isPressed ? 0.96 : 1.0)
            .animation(.easeOut(duration: 0.2), value: configuration.isPressed)
    }
}

struct SmallPrimaryButtonStyle: ButtonStyle {
    func makeBody(configuration: Configuration) -> some View {
        configuration.label
            .padding(.horizontal, 20)
            .padding(.vertical, 10)
            .background(Color.blue)
            .foregroundColor(.white)
            .cornerRadius(8)
            .scaleEffect(configuration.isPressed ? 0.95 : 1.0)
            .animation(.easeOut(duration: 0.2), value: configuration.isPressed)
    }
}

struct SmallSecondaryButtonStyle: ButtonStyle {
    func makeBody(configuration: Configuration) -> some View {
        configuration.label
            .padding(.horizontal, 20)
            .padding(.vertical, 10)
            .background(Color.gray.opacity(0.5))
            .foregroundColor(.white)
            .cornerRadius(8)
            .scaleEffect(configuration.isPressed ? 0.95 : 1.0)
            .animation(.easeOut(duration: 0.2), value: configuration.isPressed)
    }
}

struct PresetButtonStyle: ButtonStyle {
    func makeBody(configuration: Configuration) -> some View {
        configuration.label
            .padding(.horizontal, 15)
            .padding(.vertical, 8)
            .background(Color.teal.opacity(0.7))
            .foregroundColor(.white)
            .cornerRadius(6)
            .font(.subheadline)
    }
}

struct SaveButtonStyle: ButtonStyle {
    func makeBody(configuration: Configuration) -> some View {
        configuration.label
            .padding(.horizontal, 20)
            .padding(.vertical, 10)
            .background(Color.green)
            .foregroundColor(.white)
            .cornerRadius(8)
            .scaleEffect(configuration.isPressed ? 0.95 : 1.0)
            .animation(.easeOut(duration: 0.2), value: configuration.isPressed)
    }
}

struct PrintButtonStyle: ButtonStyle {
    func makeBody(configuration: Configuration) -> some View {
        configuration.label
            .padding(.horizontal, 20)
            .padding(.vertical, 10)
            .background(Color.green)
            .foregroundColor(.white)
            .cornerRadius(8)
            .scaleEffect(configuration.isPressed ? 0.95 : 1.0)
            .animation(.easeOut(duration: 0.2), value: configuration.isPressed)
    }
}

struct FilterButtonStyle: ButtonStyle {
    func makeBody(configuration: Configuration) -> some View {
        configuration.label
            .padding(.horizontal, 15)
            .padding(.vertical, 8)
            .background(Color.mint.opacity(0.7))
            .foregroundColor(.white)
            .cornerRadius(6)
            .font(.subheadline)
    }
}

// MARK: - Info Label

func iconWithInfoLabel(
    iconName: String,
    action: @escaping () -> Void,
    labelText: String,
    iconSize: CGFloat,
    showInfoMode: Bool,
    labelSide: Alignment = .trailing
) -> some View {
    Button(action: action) {
        ZStack {
            // Icon underneath the label
            Image(systemName: iconName)
                .resizable()
                .scaledToFit()
                .frame(width: iconSize, height: iconSize)

            // Label over the icon
            InfoLabel(
                text: labelText,
                color: .white.opacity(0.9),
                side: labelSide,
                width: 100,
                showInfoMode: showInfoMode
            )
            .opacity(showInfoMode ? 1 : 0)
        }
    }
}

struct InfoLabel: View {
    let text: String
    let color: Color
    let side: Alignment
    let width: CGFloat
    let showInfoMode: Bool

    var body: some View {
        Text(text)
            .font(.caption)
            .padding(6)
            .background(color)
            .foregroundColor(.black)
            .overlay(RoundedRectangle(cornerRadius: 4).stroke(Color(.gray), lineWidth: 1))
            .frame(width: width)
            .fixedSize()
            .offset(infoLabelOffset(for: side))
            .opacity(showInfoMode ? 1 : 0)
    }

    private func infoLabelOffset(for side: Alignment) -> CGSize {
        switch side {
        case .leading:
            return CGSize(width: -80, height: 0)
        case .trailing:
            return CGSize(width: 5, height: -20)
        case .top:
            return CGSize(width: 5, height: -30)
        case .bottom:
            return CGSize(width: 0, height: 30)
        default:
            return .zero
        }
    }
}

// MARK: - Alignment Extension

extension Alignment {
    static let leading = Alignment(horizontal: .leading, vertical: .center)
    static let trailing = Alignment(horizontal: .trailing, vertical: .center)
    static let top = Alignment(horizontal: .center, vertical: .top)
    static let bottom = Alignment(horizontal: .center, vertical: .bottom)
}
