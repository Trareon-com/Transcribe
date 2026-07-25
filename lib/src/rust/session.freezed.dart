// coverage:ignore-file
// GENERATED CODE - DO NOT MODIFY BY HAND
// ignore_for_file: type=lint
// ignore_for_file: unused_element, deprecated_member_use, deprecated_member_use_from_same_package, use_function_type_syntax_for_parameters, unnecessary_const, avoid_init_to_null, invalid_override_different_default_values_named, prefer_expression_function_bodies, annotate_overrides, invalid_annotation_target, unnecessary_question_mark

part of 'session.dart';

// **************************************************************************
// FreezedGenerator
// **************************************************************************

T _$identity<T>(T value) => value;

final _privateConstructorUsedError = UnsupportedError(
  'It seems like you constructed your class using `MyClass._()`. This constructor is only meant to be used by freezed and you are not supposed to need it nor use it.\nPlease check the documentation here for more information: https://github.com/rrousselGit/freezed#adding-getters-and-methods-to-our-models',
);

/// @nodoc
mixin _$SessionEvent {
  @optionalTypeArgs
  TResult when<TResult extends Object?>({
    required TResult Function(Segment field0) transcript,
    required TResult Function(String source, double level) vu,
  }) => throw _privateConstructorUsedError;
  @optionalTypeArgs
  TResult? whenOrNull<TResult extends Object?>({
    TResult? Function(Segment field0)? transcript,
    TResult? Function(String source, double level)? vu,
  }) => throw _privateConstructorUsedError;
  @optionalTypeArgs
  TResult maybeWhen<TResult extends Object?>({
    TResult Function(Segment field0)? transcript,
    TResult Function(String source, double level)? vu,
    required TResult orElse(),
  }) => throw _privateConstructorUsedError;
  @optionalTypeArgs
  TResult map<TResult extends Object?>({
    required TResult Function(SessionEvent_Transcript value) transcript,
    required TResult Function(SessionEvent_Vu value) vu,
  }) => throw _privateConstructorUsedError;
  @optionalTypeArgs
  TResult? mapOrNull<TResult extends Object?>({
    TResult? Function(SessionEvent_Transcript value)? transcript,
    TResult? Function(SessionEvent_Vu value)? vu,
  }) => throw _privateConstructorUsedError;
  @optionalTypeArgs
  TResult maybeMap<TResult extends Object?>({
    TResult Function(SessionEvent_Transcript value)? transcript,
    TResult Function(SessionEvent_Vu value)? vu,
    required TResult orElse(),
  }) => throw _privateConstructorUsedError;
}

/// @nodoc
abstract class $SessionEventCopyWith<$Res> {
  factory $SessionEventCopyWith(
    SessionEvent value,
    $Res Function(SessionEvent) then,
  ) = _$SessionEventCopyWithImpl<$Res, SessionEvent>;
}

/// @nodoc
class _$SessionEventCopyWithImpl<$Res, $Val extends SessionEvent>
    implements $SessionEventCopyWith<$Res> {
  _$SessionEventCopyWithImpl(this._value, this._then);

  // ignore: unused_field
  final $Val _value;
  // ignore: unused_field
  final $Res Function($Val) _then;

  /// Create a copy of SessionEvent
  /// with the given fields replaced by the non-null parameter values.
}

/// @nodoc
abstract class _$$SessionEvent_TranscriptImplCopyWith<$Res> {
  factory _$$SessionEvent_TranscriptImplCopyWith(
    _$SessionEvent_TranscriptImpl value,
    $Res Function(_$SessionEvent_TranscriptImpl) then,
  ) = __$$SessionEvent_TranscriptImplCopyWithImpl<$Res>;
  @useResult
  $Res call({Segment field0});
}

/// @nodoc
class __$$SessionEvent_TranscriptImplCopyWithImpl<$Res>
    extends _$SessionEventCopyWithImpl<$Res, _$SessionEvent_TranscriptImpl>
    implements _$$SessionEvent_TranscriptImplCopyWith<$Res> {
  __$$SessionEvent_TranscriptImplCopyWithImpl(
    _$SessionEvent_TranscriptImpl _value,
    $Res Function(_$SessionEvent_TranscriptImpl) _then,
  ) : super(_value, _then);

  /// Create a copy of SessionEvent
  /// with the given fields replaced by the non-null parameter values.
  @pragma('vm:prefer-inline')
  @override
  $Res call({Object? field0 = null}) {
    return _then(
      _$SessionEvent_TranscriptImpl(
        null == field0
            ? _value.field0
            : field0 // ignore: cast_nullable_to_non_nullable
                  as Segment,
      ),
    );
  }
}

/// @nodoc

class _$SessionEvent_TranscriptImpl extends SessionEvent_Transcript {
  const _$SessionEvent_TranscriptImpl(this.field0) : super._();

  @override
  final Segment field0;

  @override
  String toString() {
    return 'SessionEvent.transcript(field0: $field0)';
  }

  @override
  bool operator ==(Object other) {
    return identical(this, other) ||
        (other.runtimeType == runtimeType &&
            other is _$SessionEvent_TranscriptImpl &&
            (identical(other.field0, field0) || other.field0 == field0));
  }

  @override
  int get hashCode => Object.hash(runtimeType, field0);

  /// Create a copy of SessionEvent
  /// with the given fields replaced by the non-null parameter values.
  @JsonKey(includeFromJson: false, includeToJson: false)
  @override
  @pragma('vm:prefer-inline')
  _$$SessionEvent_TranscriptImplCopyWith<_$SessionEvent_TranscriptImpl>
  get copyWith =>
      __$$SessionEvent_TranscriptImplCopyWithImpl<
        _$SessionEvent_TranscriptImpl
      >(this, _$identity);

  @override
  @optionalTypeArgs
  TResult when<TResult extends Object?>({
    required TResult Function(Segment field0) transcript,
    required TResult Function(String source, double level) vu,
  }) {
    return transcript(field0);
  }

  @override
  @optionalTypeArgs
  TResult? whenOrNull<TResult extends Object?>({
    TResult? Function(Segment field0)? transcript,
    TResult? Function(String source, double level)? vu,
  }) {
    return transcript?.call(field0);
  }

  @override
  @optionalTypeArgs
  TResult maybeWhen<TResult extends Object?>({
    TResult Function(Segment field0)? transcript,
    TResult Function(String source, double level)? vu,
    required TResult orElse(),
  }) {
    if (transcript != null) {
      return transcript(field0);
    }
    return orElse();
  }

  @override
  @optionalTypeArgs
  TResult map<TResult extends Object?>({
    required TResult Function(SessionEvent_Transcript value) transcript,
    required TResult Function(SessionEvent_Vu value) vu,
  }) {
    return transcript(this);
  }

  @override
  @optionalTypeArgs
  TResult? mapOrNull<TResult extends Object?>({
    TResult? Function(SessionEvent_Transcript value)? transcript,
    TResult? Function(SessionEvent_Vu value)? vu,
  }) {
    return transcript?.call(this);
  }

  @override
  @optionalTypeArgs
  TResult maybeMap<TResult extends Object?>({
    TResult Function(SessionEvent_Transcript value)? transcript,
    TResult Function(SessionEvent_Vu value)? vu,
    required TResult orElse(),
  }) {
    if (transcript != null) {
      return transcript(this);
    }
    return orElse();
  }
}

abstract class SessionEvent_Transcript extends SessionEvent {
  const factory SessionEvent_Transcript(final Segment field0) =
      _$SessionEvent_TranscriptImpl;
  const SessionEvent_Transcript._() : super._();

  Segment get field0;

  /// Create a copy of SessionEvent
  /// with the given fields replaced by the non-null parameter values.
  @JsonKey(includeFromJson: false, includeToJson: false)
  _$$SessionEvent_TranscriptImplCopyWith<_$SessionEvent_TranscriptImpl>
  get copyWith => throw _privateConstructorUsedError;
}

/// @nodoc
abstract class _$$SessionEvent_VuImplCopyWith<$Res> {
  factory _$$SessionEvent_VuImplCopyWith(
    _$SessionEvent_VuImpl value,
    $Res Function(_$SessionEvent_VuImpl) then,
  ) = __$$SessionEvent_VuImplCopyWithImpl<$Res>;
  @useResult
  $Res call({String source, double level});
}

/// @nodoc
class __$$SessionEvent_VuImplCopyWithImpl<$Res>
    extends _$SessionEventCopyWithImpl<$Res, _$SessionEvent_VuImpl>
    implements _$$SessionEvent_VuImplCopyWith<$Res> {
  __$$SessionEvent_VuImplCopyWithImpl(
    _$SessionEvent_VuImpl _value,
    $Res Function(_$SessionEvent_VuImpl) _then,
  ) : super(_value, _then);

  /// Create a copy of SessionEvent
  /// with the given fields replaced by the non-null parameter values.
  @pragma('vm:prefer-inline')
  @override
  $Res call({Object? source = null, Object? level = null}) {
    return _then(
      _$SessionEvent_VuImpl(
        source: null == source
            ? _value.source
            : source // ignore: cast_nullable_to_non_nullable
                  as String,
        level: null == level
            ? _value.level
            : level // ignore: cast_nullable_to_non_nullable
                  as double,
      ),
    );
  }
}

/// @nodoc

class _$SessionEvent_VuImpl extends SessionEvent_Vu {
  const _$SessionEvent_VuImpl({required this.source, required this.level})
    : super._();

  @override
  final String source;
  @override
  final double level;

  @override
  String toString() {
    return 'SessionEvent.vu(source: $source, level: $level)';
  }

  @override
  bool operator ==(Object other) {
    return identical(this, other) ||
        (other.runtimeType == runtimeType &&
            other is _$SessionEvent_VuImpl &&
            (identical(other.source, source) || other.source == source) &&
            (identical(other.level, level) || other.level == level));
  }

  @override
  int get hashCode => Object.hash(runtimeType, source, level);

  /// Create a copy of SessionEvent
  /// with the given fields replaced by the non-null parameter values.
  @JsonKey(includeFromJson: false, includeToJson: false)
  @override
  @pragma('vm:prefer-inline')
  _$$SessionEvent_VuImplCopyWith<_$SessionEvent_VuImpl> get copyWith =>
      __$$SessionEvent_VuImplCopyWithImpl<_$SessionEvent_VuImpl>(
        this,
        _$identity,
      );

  @override
  @optionalTypeArgs
  TResult when<TResult extends Object?>({
    required TResult Function(Segment field0) transcript,
    required TResult Function(String source, double level) vu,
  }) {
    return vu(source, level);
  }

  @override
  @optionalTypeArgs
  TResult? whenOrNull<TResult extends Object?>({
    TResult? Function(Segment field0)? transcript,
    TResult? Function(String source, double level)? vu,
  }) {
    return vu?.call(source, level);
  }

  @override
  @optionalTypeArgs
  TResult maybeWhen<TResult extends Object?>({
    TResult Function(Segment field0)? transcript,
    TResult Function(String source, double level)? vu,
    required TResult orElse(),
  }) {
    if (vu != null) {
      return vu(source, level);
    }
    return orElse();
  }

  @override
  @optionalTypeArgs
  TResult map<TResult extends Object?>({
    required TResult Function(SessionEvent_Transcript value) transcript,
    required TResult Function(SessionEvent_Vu value) vu,
  }) {
    return vu(this);
  }

  @override
  @optionalTypeArgs
  TResult? mapOrNull<TResult extends Object?>({
    TResult? Function(SessionEvent_Transcript value)? transcript,
    TResult? Function(SessionEvent_Vu value)? vu,
  }) {
    return vu?.call(this);
  }

  @override
  @optionalTypeArgs
  TResult maybeMap<TResult extends Object?>({
    TResult Function(SessionEvent_Transcript value)? transcript,
    TResult Function(SessionEvent_Vu value)? vu,
    required TResult orElse(),
  }) {
    if (vu != null) {
      return vu(this);
    }
    return orElse();
  }
}

abstract class SessionEvent_Vu extends SessionEvent {
  const factory SessionEvent_Vu({
    required final String source,
    required final double level,
  }) = _$SessionEvent_VuImpl;
  const SessionEvent_Vu._() : super._();

  String get source;
  double get level;

  /// Create a copy of SessionEvent
  /// with the given fields replaced by the non-null parameter values.
  @JsonKey(includeFromJson: false, includeToJson: false)
  _$$SessionEvent_VuImplCopyWith<_$SessionEvent_VuImpl> get copyWith =>
      throw _privateConstructorUsedError;
}
