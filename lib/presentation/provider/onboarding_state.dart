import 'package:boorunova/boorus/engine/booru_type.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

/// 引导流程的跨重建状态。
///
/// 语言切换会让 MaterialApp 以 locale 为 key 整树重建，从而销毁引导页的
/// 本地 State。把「当前步骤、已勾选站点」提升到 provider，重建后仍保留。
class OnboardingState {
  OnboardingState({this.step = 0, Set<BooruType>? selected})
      : selected = selected ?? <BooruType>{};

  final int step;
  final Set<BooruType> selected;

  OnboardingState copyWith({int? step, Set<BooruType>? selected}) {
    return OnboardingState(
      step: step ?? this.step,
      selected: selected ?? this.selected,
    );
  }
}

class OnboardingNotifier extends Notifier<OnboardingState> {
  @override
  OnboardingState build() {
    // Safebooru 为默认全年龄站点，预勾选
    return OnboardingState(
      selected: {BooruType.safebooru},
    );
  }

  void setStep(int step) => state = state.copyWith(step: step);

  void toggle(BooruType type, bool on) {
    final next = Set<BooruType>.of(state.selected);
    if (on) {
      next.add(type);
    } else {
      next.remove(type);
    }
    state = state.copyWith(selected: next);
  }

  void preset(Set<BooruType> selected) {
    state = state.copyWith(selected: selected);
  }

  /// 引导结束时重置为初始态，避免下次（如重新引导）残留旧勾选。
  void reset() => state = OnboardingState(selected: {BooruType.safebooru});
}

final onboardingProvider =
    NotifierProvider<OnboardingNotifier, OnboardingState>(OnboardingNotifier.new);
