import ActivityKit
import WidgetKit
import SwiftUI

@main
struct MedCasesActivityBundle: WidgetBundle {
    var body: some Widget {
        OrganizationTimerWidget()
        RecordingActivityWidget()
    }
}

struct OrganizationTimerWidget: Widget {
    var body: some WidgetConfiguration {
        ActivityConfiguration(for: MedCasesTimerAttributes.self) { context in
            HStack(alignment: .center, spacing: 14) {
                brandMark(size: 44)
                VStack(alignment: .leading, spacing: 5) {
                    Text("MEDCASES").font(.caption.weight(.semibold)).tracking(1.4).foregroundStyle(.primary)
                    Text("Timer").font(.caption).foregroundStyle(.secondary)
                }
                Spacer(minLength: 8)
                VStack(alignment: .trailing, spacing: 5) {
                    timer(context)
                        .font(.system(size: 36, weight: .medium, design: .rounded))
                        .foregroundStyle(.primary).multilineTextAlignment(.trailing)
                        .minimumScaleFactor(0.7).lineLimit(1)
                    Text(status(context)).font(.caption).foregroundStyle(.secondary)
                }
            }
            .padding(20)
            .activityBackgroundTint(Color(uiColor: .secondarySystemBackground))
            .activitySystemActionForegroundColor(Color(uiColor: .label))
        } dynamicIsland: { context in
            DynamicIsland {
                DynamicIslandExpandedRegion(.leading) { brandMark(size: 38).padding(.leading, 12).padding(.top, 6) }
                DynamicIslandExpandedRegion(.trailing) {
                    timer(context).font(.system(size: 30, weight: .medium, design: .rounded))
                        .foregroundStyle(.white).multilineTextAlignment(.trailing)
                        .lineLimit(1).minimumScaleFactor(0.6).frame(width: 142)
                        .padding(.trailing, 12).padding(.top, 6)
                }
                DynamicIslandExpandedRegion(.bottom) {
                    Text(status(context)).font(.caption).foregroundStyle(.white.opacity(0.7))
                        .frame(maxWidth: .infinity, alignment: .trailing)
                        .padding(.horizontal, 12).padding(.bottom, 8)
                }
            } compactLeading: { brandMark(size: 20) }
              compactTrailing: { timer(context).font(.system(size: 12, weight: .semibold, design: .rounded)).foregroundStyle(.white).multilineTextAlignment(.trailing).lineLimit(1).minimumScaleFactor(0.6).frame(width: 58) }
              minimal: {
                  // iOS uses this small region when another activity shares the Island.
                  // Prioritize the countdown instead of shrinking both the mark and digits.
                  timer(context)
                      .font(.system(size: 12, weight: .semibold, design: .rounded))
                      .foregroundStyle(.white).multilineTextAlignment(.center)
                      .lineLimit(1).minimumScaleFactor(0.75)
                      .frame(width: 40, alignment: .center)
              }
        }
    }
    private func brandMark(size: CGFloat) -> some View {
        Image("MedCasesMark").resizable().scaledToFit()
            .frame(width: size, height: size)
            .clipShape(RoundedRectangle(cornerRadius: size * 0.25))
            .accessibilityLabel("MedCases")
    }
    private func status(_ context: ActivityViewContext<MedCasesTimerAttributes>) -> String {
        context.state.status == "paused" ? (context.state.isEs ? "En pausa" : "Pausado") :
          (context.isStale ? "Timer finalizado" : (context.state.isEs ? "En curso" : "Em andamento"))
    }
    @ViewBuilder
    private func timer(_ context: ActivityViewContext<MedCasesTimerAttributes>) -> some View {
        if context.state.status == "running" && !context.isStale {
            Text(timerInterval: Date.distantPast...context.state.end, countsDown: true).monospacedDigit()
        } else if context.state.status == "paused" {
            Text(String(format: "%02d:%02d", context.state.remaining / 60, context.state.remaining % 60)).monospacedDigit()
        } else { Text("00:00").monospacedDigit() }
    }
}

struct RecordingActivityWidget: Widget {
    var body: some WidgetConfiguration {
        ActivityConfiguration(for: MedCasesRecordingAttributes.self) { context in
            HStack(spacing: 14) {
                logo(44)
                VStack(alignment: .leading, spacing: 5) {
                    Text("MEDCASES").font(.caption.weight(.semibold)).tracking(1.4)
                    Label(status(context), systemImage: "mic.fill").font(.caption).foregroundStyle(.secondary)
                }
                Spacer(minLength: 8)
                elapsed(context).font(.system(size: 32, weight: .medium, design: .rounded))
                    .lineLimit(1).minimumScaleFactor(0.6).multilineTextAlignment(.trailing)
            }.padding(20)
             .activityBackgroundTint(Color(uiColor: .secondarySystemBackground))
             .activitySystemActionForegroundColor(Color(uiColor: .label))
        } dynamicIsland: { context in
            DynamicIsland {
                DynamicIslandExpandedRegion(.leading) { logo(38).padding(.leading, 12).padding(.top, 6) }
                DynamicIslandExpandedRegion(.trailing) {
                    elapsed(context).font(.system(size: 30, weight: .medium, design: .rounded))
                        .multilineTextAlignment(.trailing).lineLimit(1).minimumScaleFactor(0.6)
                        .frame(width: 142).padding(.trailing, 12).padding(.top, 6)
                }
                DynamicIslandExpandedRegion(.bottom) {
                    Text(status(context)).font(.caption).foregroundStyle(.white.opacity(0.7))
                        .frame(maxWidth: .infinity, alignment: .trailing)
                        .padding(.horizontal, 12).padding(.bottom, 8)
                }
            } compactLeading: { logo(20) }
              compactTrailing: {
                elapsed(context).font(.system(size: 12, weight: .semibold, design: .rounded))
                    .lineLimit(1).minimumScaleFactor(0.6).multilineTextAlignment(.trailing).frame(width: 58)
              } minimal: {
                HStack(spacing: 2) {
                    logo(10)
                    elapsed(context).font(.system(size: 9, weight: .semibold))
                        .lineLimit(1).minimumScaleFactor(0.5).frame(width: 27)
                }
              }
        }
    }
    private func logo(_ size: CGFloat) -> some View {
        Image("MedCasesMark").resizable().scaledToFit().frame(width: size, height: size)
            .clipShape(RoundedRectangle(cornerRadius: size * 0.22)).accessibilityLabel("MedCases")
    }
    private func status(_ context: ActivityViewContext<MedCasesRecordingAttributes>) -> String {
        if context.isStale { return context.state.isEs ? "Abre la grabación" : "Abra a gravação" }
        return context.state.status == "paused" ? (context.state.isEs ? "En pausa" : "Pausado") :
            (context.state.isEs ? "Grabando" : "Gravando")
    }
    @ViewBuilder private func elapsed(_ context: ActivityViewContext<MedCasesRecordingAttributes>) -> some View {
        if context.state.status == "recording" && !context.isStale {
            Text(timerInterval: context.state.startedAt...Date.distantFuture, countsDown: false).monospacedDigit()
        } else {
            Text(String(format: "%02d:%02d", context.state.elapsedSeconds / 60, context.state.elapsedSeconds % 60)).monospacedDigit()
        }
    }
}
