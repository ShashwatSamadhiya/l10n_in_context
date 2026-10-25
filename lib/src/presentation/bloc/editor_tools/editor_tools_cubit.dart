import 'package:equatable/equatable.dart';
import 'package:flutter_bloc/flutter_bloc.dart';

/// The editor's on-screen tools.
class EditorToolsState extends Equatable {
  /// Creates the state; every tool starts off.
  const EditorToolsState({this.pickMode = false, this.highlight = false});

  /// The next tap selects a text on screen instead of reaching the app.
  final bool pickMode;

  /// Every tagged string on screen is outlined.
  final bool highlight;

  /// A copy with the given fields replaced.
  EditorToolsState copyWith({bool? pickMode, bool? highlight}) =>
      EditorToolsState(
        pickMode: pickMode ?? this.pickMode,
        highlight: highlight ?? this.highlight,
      );

  @override
  List<Object?> get props => [pickMode, highlight];
}

/// Switches the editor's on-screen tools.
class EditorToolsCubit extends Cubit<EditorToolsState> {
  /// Starts with every tool off.
  EditorToolsCubit() : super(const EditorToolsState());

  /// Turns pick mode on or off.
  void togglePickMode() => emit(state.copyWith(pickMode: !state.pickMode));

  /// Sets pick mode.
  void setPickMode(bool value) => emit(state.copyWith(pickMode: value));

  /// Turns highlighting on or off.
  void toggleHighlight() => emit(state.copyWith(highlight: !state.highlight));

  /// Turns every tool off, e.g. when edit access ends.
  void reset() => emit(const EditorToolsState());
}
