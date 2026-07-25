import SwiftUI
import UIKit

/// Full-screen image viewer with pinch-to-zoom, pan, and double-tap zoom.
struct FullScreenImageViewer: View {
    let image: UIImage
    @Environment(\.dismiss) private var dismiss

    var body: some View {
        ZStack(alignment: .topTrailing) {
            Color.black.ignoresSafeArea()

            ZoomableScrollView(image: image)
                .ignoresSafeArea()

            Button {
                dismiss()
            } label: {
                Image(systemName: "xmark.circle.fill")
                    .font(.title)
                    .symbolRenderingMode(.palette)
                    .foregroundStyle(.white, .white.opacity(0.35))
                    .padding(16)
            }
            .accessibilityLabel("Close")
        }
        .statusBarHidden(true)
    }
}

/// UIScrollView wrapper — reliable pinch zoom + pan on iOS 16.
private struct ZoomableScrollView: UIViewRepresentable {
    let image: UIImage

    func makeCoordinator() -> Coordinator {
        Coordinator()
    }

    func makeUIView(context: Context) -> UIScrollView {
        let scrollView = UIScrollView()
        scrollView.delegate = context.coordinator
        scrollView.backgroundColor = .black
        scrollView.showsHorizontalScrollIndicator = false
        scrollView.showsVerticalScrollIndicator = false
        scrollView.bouncesZoom = true
        scrollView.contentInsetAdjustmentBehavior = .never

        let imageView = UIImageView(image: image)
        imageView.contentMode = .scaleAspectFit
        imageView.isUserInteractionEnabled = true
        scrollView.addSubview(imageView)

        context.coordinator.scrollView = scrollView
        context.coordinator.imageView = imageView

        let doubleTap = UITapGestureRecognizer(
            target: context.coordinator,
            action: #selector(Coordinator.handleDoubleTap(_:))
        )
        doubleTap.numberOfTapsRequired = 2
        scrollView.addGestureRecognizer(doubleTap)

        return scrollView
    }

    func updateUIView(_ scrollView: UIScrollView, context: Context) {
        context.coordinator.imageView?.image = image
        // Layout after the next run loop so bounds are valid.
        DispatchQueue.main.async {
            context.coordinator.layoutImageIfNeeded()
        }
    }

    final class Coordinator: NSObject, UIScrollViewDelegate {
        weak var scrollView: UIScrollView?
        weak var imageView: UIImageView?
        private var lastBoundsSize: CGSize = .zero

        func viewForZooming(in scrollView: UIScrollView) -> UIView? {
            imageView
        }

        func scrollViewDidZoom(_ scrollView: UIScrollView) {
            centerImage()
        }

        func layoutImageIfNeeded() {
            guard let scrollView, let imageView, let image = imageView.image else { return }
            let boundsSize = scrollView.bounds.size
            guard boundsSize.width > 0, boundsSize.height > 0 else { return }

            // Avoid resetting zoom while the user is interacting, unless bounds changed (rotation).
            let boundsChanged = boundsSize != lastBoundsSize
            lastBoundsSize = boundsSize

            imageView.frame = CGRect(origin: .zero, size: image.size)
            scrollView.contentSize = image.size

            let widthScale = boundsSize.width / image.size.width
            let heightScale = boundsSize.height / image.size.height
            let fitScale = min(widthScale, heightScale)

            scrollView.minimumZoomScale = fitScale
            scrollView.maximumZoomScale = max(fitScale * 4, 1)

            if boundsChanged || scrollView.zoomScale < fitScale {
                scrollView.zoomScale = fitScale
            }
            centerImage()
        }

        private func centerImage() {
            guard let scrollView, let imageView else { return }
            let boundsSize = scrollView.bounds.size
            let contentSize = imageView.frame.size

            let horizontalInset = max(0, (boundsSize.width - contentSize.width) / 2)
            let verticalInset = max(0, (boundsSize.height - contentSize.height) / 2)
            scrollView.contentInset = UIEdgeInsets(
                top: verticalInset,
                left: horizontalInset,
                bottom: verticalInset,
                right: horizontalInset
            )
        }

        @objc func handleDoubleTap(_ gesture: UITapGestureRecognizer) {
            guard let scrollView else { return }
            if scrollView.zoomScale > scrollView.minimumZoomScale + 0.01 {
                scrollView.setZoomScale(scrollView.minimumZoomScale, animated: true)
            } else {
                let point = gesture.location(in: imageView)
                let target = min(scrollView.maximumZoomScale, scrollView.minimumZoomScale * 2.5)
                let size = CGSize(
                    width: scrollView.bounds.width / target,
                    height: scrollView.bounds.height / target
                )
                let origin = CGPoint(x: point.x - size.width / 2, y: point.y - size.height / 2)
                scrollView.zoom(to: CGRect(origin: origin, size: size), animated: true)
            }
        }
    }
}
