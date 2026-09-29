import SwiftUI

/// RITUAL C — Reading Glass. STEP 1 PLACEHOLDER.
///
/// The camera, ARKit and Vision arrive in Step 3. This is NOT an error state
/// and it is not hidden: the chip stays in the dock and explains itself,
/// because a missing button looks broken and a hidden button looks like a lie.
///
/// The composition below is the real intended layout — jar around the book,
/// reticle over the focus object — drawn statically so the design is complete
/// and reviewable now, and so Step 3 only has to make it live.
struct ReadingGlassView: View {
    @Environment(AppState.self) private var state
    @Environment(\.colorScheme) private var scheme

    let namespace: Namespace.ID

    var body: some View {
        ZStack {
            RitualBackdrop()

            GeometryReader { proxy in
                let size = proxy.size
                Canvas { ctx, _ in
                    let colors = WorldColors.make(dark: scheme == .dark)

                    // The book on the desk, seen through the jar.
                    let book = CGRect(x: size.width * 0.30, y: size.height * 0.48,
                                      width: size.width * 0.40, height: size.height * 0.24)
                    let cover = Path(roundedRect: book, cornerRadius: 8, style: .continuous)
                    ctx.fill(cover, with: .color(colors.bark.opacity(0.55)))
                    // Pages
                    let pages = book.insetBy(dx: book.width * 0.06, dy: book.height * 0.14)
                    ctx.fill(Path(roundedRect: pages, cornerRadius: 4, style: .continuous),
                             with: .color(Color.white.opacity(scheme == .dark ? 0.62 : 0.86)))
                    // Spine
                    var spine = Path()
                    spine.move(to: CGPoint(x: book.midX, y: pages.minY))
                    spine.addLine(to: CGPoint(x: book.midX, y: pages.maxY))
                    ctx.stroke(spine, with: .color(colors.bark.opacity(0.45)), lineWidth: 2)
                    // Text lines
                    for i in 0..<5 {
                        let y = pages.minY + pages.height * (0.16 + Double(i) * 0.16)
                        var l = Path()
                        l.move(to: CGPoint(x: pages.minX + 10, y: y))
                        l.addLine(to: CGPoint(x: pages.maxX - 10 - CGFloat(i % 3) * 22, y: y))
                        ctx.stroke(l, with: .color(Color.black.opacity(0.16)),
                                   style: StrokeStyle(lineWidth: 2.4, lineCap: .round))
                    }

                    // The T3 Breath-tier reticle, settled around the book.
                    let ret = book.insetBy(dx: -18, dy: -18)
                    for corner in 0..<4 {
                        let x = corner < 2 ? ret.minX : ret.maxX
                        let y = corner % 3 == 0 ? ret.minY : ret.maxY
                        let dx: CGFloat = corner < 2 ? 1 : -1
                        let dy: CGFloat = (corner == 0 || corner == 1) ? 1 : -1
                        var c = Path()
                        c.move(to: CGPoint(x: x + dx * 26, y: y))
                        c.addLine(to: CGPoint(x: x, y: y))
                        c.addLine(to: CGPoint(x: x, y: y + dy * 26))
                        ctx.stroke(c, with: .color(colors.pollen.opacity(0.75)),
                                   style: StrokeStyle(lineWidth: 3, lineCap: .round, lineJoin: .round))
                    }

                    // Pollen arcing from the page into the soil: the mechanic
                    // that makes reading visible. One sprite, no text.
                    let from = CGPoint(x: book.midX, y: book.minY)
                    let to = CGPoint(x: size.width * 0.5, y: size.height * 0.86)
                    var arc = Path()
                    arc.move(to: from)
                    arc.addQuadCurve(to: to, control: CGPoint(x: from.x + 90, y: from.y - 120))
                    ctx.stroke(arc, with: .color(colors.pollen.opacity(0.20)),
                               style: StrokeStyle(lineWidth: 2, lineCap: .round,
                                                  dash: [3, 9]))
                }
            }

            VStack {
                HStack {
                    Button { state.endRitual(completed: false) } label: {
                        Image(systemName: BloomSymbol.close)
                            .font(.system(.body, design: .rounded).weight(.semibold))
                            .foregroundStyle(.primary)
                            .frame(width: 46, height: 46)
                            .bloomGlass(.fitting, shape: BloomShape.circle)
                    }
                    .buttonStyle(.plain)
                    .accessibilityLabel("Leave the ritual")
                    Spacer()
                }
                .padding(.horizontal, 24)
                .padding(.top, 12)

                Spacer()

                VStack(spacing: 10) {
                    Image(systemName: BloomSymbol.read)
                        .font(.system(.title, design: .rounded))
                        .foregroundStyle(.secondary)
                    Text(BloomCopy.readStubTitle)
                        .font(.bloomTitle)
                        .multilineTextAlignment(.center)
                    Text(BloomCopy.readStubBody)
                        .font(.bloomCaption)
                        .foregroundStyle(.secondary)
                        .multilineTextAlignment(.center)
                        .frame(maxWidth: 380)
                }
                .padding(22)
                .bloomGlass(.wall, shape: BloomShape.panel(26))
                .matchedGeometryEffect(id: "hud-prompt", in: namespace, isSource: true)
                .padding(.bottom, 40)
            }
        }
        .onDisappear { state.engine.input = .idle }
    }
}
