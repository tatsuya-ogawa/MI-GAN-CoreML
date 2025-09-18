//
//  ParticleSystemView.swift
//  iOS-InPainting
//
//  Created by Tatsuya Ogawa on 2025/09/18.
//

import SwiftUI
import CoreGraphics

struct Particle {
    var position: CGPoint
    var velocity: CGVector
    var alpha: Double
    var size: CGFloat
    var age: Double
    var maxAge: Double

    init(position: CGPoint) {
        self.position = position
        self.velocity = CGVector(dx: 0, dy: 0)
        self.alpha = 1.0
        self.size = CGFloat.random(in: 2...6)
        self.age = 0
        self.maxAge = Double.random(in: 1.0...3.0)
    }

    var isAlive: Bool {
        return age < maxAge && alpha > 0.01
    }
}

class ParticleSystem: ObservableObject {
    @Published var particles: [Particle] = []
    private var displayLink: CADisplayLink?
    private var lastUpdateTime: CFTimeInterval = 0
    private var noiseOffset: Double = 0

    func startAnimation(maskImage: UIImage, imageSize: CGSize) {
        generateParticlesFromMask(maskImage: maskImage, imageSize: imageSize)
        startDisplayLink()
    }

    func stopAnimation() {
        displayLink?.invalidate()
        displayLink = nil
        particles.removeAll()
    }

    private func generateParticlesFromMask(maskImage: UIImage, imageSize: CGSize) {
        guard let cgImage = maskImage.cgImage else { return }

        let width = cgImage.width
        let height = cgImage.height
        let bytesPerPixel = 4
        let bytesPerRow = width * bytesPerPixel
        let totalBytes = height * bytesPerRow

        var pixelData = Data(count: totalBytes)
        let colorSpace = CGColorSpaceCreateDeviceRGB()

        pixelData.withUnsafeMutableBytes { bytes in
            guard let context = CGContext(
                data: bytes.baseAddress,
                width: width,
                height: height,
                bitsPerComponent: 8,
                bytesPerRow: bytesPerRow,
                space: colorSpace,
                bitmapInfo: CGImageAlphaInfo.premultipliedLast.rawValue
            ) else { return }

            context.draw(cgImage, in: CGRect(x: 0, y: 0, width: width, height: height))
        }

        let pixels = pixelData.withUnsafeBytes { $0.bindMemory(to: UInt8.self) }
        var newParticles: [Particle] = []

        let sampleRate = 8
        for y in stride(from: 0, to: height, by: sampleRate) {
            for x in stride(from: 0, to: width, by: sampleRate) {
                let pixelIndex = y * width + x
                let byteIndex = pixelIndex * 4

                if byteIndex < pixels.count {
                    let red = pixels[byteIndex]

                    if red > 128 {
                        let normalizedX = CGFloat(x) / CGFloat(width) * imageSize.width
                        let normalizedY = CGFloat(y) / CGFloat(height) * imageSize.height
                        let particle = Particle(position: CGPoint(x: normalizedX, y: normalizedY))
                        newParticles.append(particle)
                    }
                }
            }
        }

        particles = newParticles
    }

    private func startDisplayLink() {
        displayLink = CADisplayLink(target: self, selector: #selector(updateParticles))
        displayLink?.add(to: .main, forMode: .common)
    }

    @objc private func updateParticles() {
        let currentTime = CACurrentMediaTime()
        let deltaTime = currentTime - lastUpdateTime
        lastUpdateTime = currentTime

        if deltaTime > 1.0 / 30.0 { return }

        noiseOffset += deltaTime * 0.5

        for i in 0..<particles.count {
            updateParticle(at: i, deltaTime: deltaTime)
        }

        particles.removeAll { !$0.isAlive }

        if particles.isEmpty {
            stopAnimation()
        }
    }

    private func updateParticle(at index: Int, deltaTime: CFTimeInterval) {
        var particle = particles[index]

        let noiseX = curlNoise(x: Double(particle.position.x) * 0.01, y: Double(particle.position.y) * 0.01, time: noiseOffset).x
        let noiseY = curlNoise(x: Double(particle.position.x) * 0.01, y: Double(particle.position.y) * 0.01, time: noiseOffset).y

        particle.velocity.dx += CGFloat(noiseX) * 100
        particle.velocity.dy += CGFloat(noiseY) * 100

        particle.velocity.dx *= 0.98
        particle.velocity.dy *= 0.98

        particle.position.x += particle.velocity.dx * CGFloat(deltaTime)
        particle.position.y += particle.velocity.dy * CGFloat(deltaTime)

        particle.age += deltaTime
        particle.alpha = max(0, 1.0 - (particle.age / particle.maxAge))

        particles[index] = particle
    }

    private func curlNoise(x: Double, y: Double, time: Double) -> (x: Double, y: Double) {
        let epsilon = 0.001

        let n1 = noise(x: x, y: y + epsilon, time: time)
        let n2 = noise(x: x, y: y - epsilon, time: time)
        let n3 = noise(x: x + epsilon, y: y, time: time)
        let n4 = noise(x: x - epsilon, y: y, time: time)

        let curlX = (n1 - n2) / (2.0 * epsilon)
        let curlY = (n4 - n3) / (2.0 * epsilon)

        return (x: curlX, y: curlY)
    }

    private func noise(x: Double, y: Double, time: Double) -> Double {
        let x = x + time * 0.1
        let y = y + time * 0.1

        return sin(x * 12.9898 + y * 78.233 + time) * 43758.5453
            .truncatingRemainder(dividingBy: 1.0)
    }
}

struct ParticleSystemView: View {
    @StateObject private var particleSystem = ParticleSystem()
    let maskImage: UIImage?
    let imageSize: CGSize
    let isShowingMask: Bool
    @State private var shouldAnimate = false

    var body: some View {
        Canvas { context, size in
            for particle in particleSystem.particles {
                if particle.position.x >= 0 && particle.position.x <= size.width &&
                   particle.position.y >= 0 && particle.position.y <= size.height {

                    let rect = CGRect(
                        x: particle.position.x - particle.size / 2,
                        y: particle.position.y - particle.size / 2,
                        width: particle.size,
                        height: particle.size
                    )

                    let color: Color = isShowingMask ? .red.opacity(0.8) : .white
                    context.fill(
                        Path(ellipseIn: rect),
                        with: .color(color.opacity(particle.alpha))
                    )
                }
            }
        }
        .onAppear {
            if shouldAnimate, let maskImage = maskImage {
                particleSystem.startAnimation(maskImage: maskImage, imageSize: imageSize)
            }
        }
        .onChange(of: shouldAnimate) { _, newValue in
            if newValue, let maskImage = maskImage {
                particleSystem.startAnimation(maskImage: maskImage, imageSize: imageSize)
            } else {
                particleSystem.stopAnimation()
            }
        }
    }

    func startAnimation() {
        shouldAnimate = true
    }

    func stopAnimation() {
        shouldAnimate = false
    }
}