import SwiftUI

struct ConfettiView: View {
    @State private var time: Double = 0.0
    @State private var particles: [Particle] = []
    
    var body: some View {
        TimelineView(.animation) { timeline in
            Canvas { context, size in
                let now = timeline.date.timeIntervalSinceReferenceDate
                // delta removed
                
                for particle in particles {
                    let p = particle
                    let x = p.x
                    let y = p.y + (p.speed * 2) // Move down
                    
                    // Simple sway
                    let sway = sin(now * p.swaySpeed + p.id) * 2
                    
                    if y < size.height {
                        let rect = CGRect(x: x + sway, y: y, width: 8, height: 8)
                        var particleContext = context
                        particleContext.rotate(by: .degrees(now * p.rotationSpeed))
                        particleContext.fill(
                            Path(ellipseIn: rect),
                            with: .color(p.color)
                        )
                    }
                }
            }
            .onChange(of: timeline.date) { _, newValue in
                time = newValue.timeIntervalSinceReferenceDate
                updateParticles(in: UIScreen.main.bounds.size)
            }
        }
        .onAppear {
            createParticles()
        }
        .ignoresSafeArea()
    }
    
    private func createParticles() {
        var newParticles: [Particle] = []
        for i in 0..<100 {
            newParticles.append(Particle(
                id: Double(i),
                x: Double.random(in: 0...UIScreen.main.bounds.width),
                y: Double.random(in: -UIScreen.main.bounds.height...0), // Start above screen
                speed: Double.random(in: 2...5),
                swaySpeed: Double.random(in: 1...3),
                rotationSpeed: Double.random(in: 50...200),
                color: [AppColors.functionalExpense, Color.blue, AppColors.functionalIncome, Color.yellow, Color.purple, Color.orange].randomElement()!
            ))
        }
        particles = newParticles
    }
    
    private func updateParticles(in size: CGSize) {
        for i in 0..<particles.count {
            if particles[i].y > size.height {
                particles[i].y = Double.random(in: -100...0)
                particles[i].x = Double.random(in: 0...size.width)
            } else {
                particles[i].y += particles[i].speed
            }
        }
    }
    
    struct Particle {
        let id: Double
        var x: Double
        var y: Double
        let speed: Double
        let swaySpeed: Double
        let rotationSpeed: Double
        let color: Color
    }
}
