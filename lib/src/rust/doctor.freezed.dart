// coverage:ignore-file
// GENERATED CODE - DO NOT MODIFY BY HAND
// ignore_for_file: type=lint
// ignore_for_file: unused_element, deprecated_member_use, deprecated_member_use_from_same_package, use_function_type_syntax_for_parameters, unnecessary_const, avoid_init_to_null, invalid_override_different_default_values_named, prefer_expression_function_bodies, annotate_overrides, invalid_annotation_target, unnecessary_question_mark

part of 'doctor.dart';

// **************************************************************************
// FreezedGenerator
// **************************************************************************

T _$identity<T>(T value) => value;

final _privateConstructorUsedError = UnsupportedError(
  'It seems like you constructed your class using `MyClass._()`. This constructor is only meant to be used by freezed and you are not supposed to need it nor use it.\nPlease check the documentation here for more information: https://github.com/rrousselGit/freezed#adding-getters-and-methods-to-our-models',
);

/// @nodoc
mixin _$CheckStatus {
  @optionalTypeArgs
  TResult when<TResult extends Object?>({
    required TResult Function() ok,
    required TResult Function(String field0) warn,
    required TResult Function(String field0) fail,
  }) => throw _privateConstructorUsedError;
  @optionalTypeArgs
  TResult? whenOrNull<TResult extends Object?>({
    TResult? Function()? ok,
    TResult? Function(String field0)? warn,
    TResult? Function(String field0)? fail,
  }) => throw _privateConstructorUsedError;
  @optionalTypeArgs
  TResult maybeWhen<TResult extends Object?>({
    TResult Function()? ok,
    TResult Function(String field0)? warn,
    TResult Function(String field0)? fail,
    required TResult orElse(),
  }) => throw _privateConstructorUsedError;
  @optionalTypeArgs
  TResult map<TResult extends Object?>({
    required TResult Function(CheckStatus_Ok value) ok,
    required TResult Function(CheckStatus_Warn value) warn,
    required TResult Function(CheckStatus_Fail value) fail,
  }) => throw _privateConstructorUsedError;
  @optionalTypeArgs
  TResult? mapOrNull<TResult extends Object?>({
    TResult? Function(CheckStatus_Ok value)? ok,
    TResult? Function(CheckStatus_Warn value)? warn,
    TResult? Function(CheckStatus_Fail value)? fail,
  }) => throw _privateConstructorUsedError;
  @optionalTypeArgs
  TResult maybeMap<TResult extends Object?>({
    TResult Function(CheckStatus_Ok value)? ok,
    TResult Function(CheckStatus_Warn value)? warn,
    TResult Function(CheckStatus_Fail value)? fail,
    required TResult orElse(),
  }) => throw _privateConstructorUsedError;
}

/// @nodoc
abstract class $CheckStatusCopyWith<$Res> {
  factory $CheckStatusCopyWith(
    CheckStatus value,
    $Res Function(CheckStatus) then,
  ) = _$CheckStatusCopyWithImpl<$Res, CheckStatus>;
}

/// @nodoc
class _$CheckStatusCopyWithImpl<$Res, $Val extends CheckStatus>
    implements $CheckStatusCopyWith<$Res> {
  _$CheckStatusCopyWithImpl(this._value, this._then);

  // ignore: unused_field
  final $Val _value;
  // ignore: unused_field
  final $Res Function($Val) _then;

  /// Create a copy of CheckStatus
  /// with the given fields replaced by the non-null parameter values.
}

/// @nodoc
abstract class _$$CheckStatus_OkImplCopyWith<$Res> {
  factory _$$CheckStatus_OkImplCopyWith(
    _$CheckStatus_OkImpl value,
    $Res Function(_$CheckStatus_OkImpl) then,
  ) = __$$CheckStatus_OkImplCopyWithImpl<$Res>;
}

/// @nodoc
class __$$CheckStatus_OkImplCopyWithImpl<$Res>
    extends _$CheckStatusCopyWithImpl<$Res, _$CheckStatus_OkImpl>
    implements _$$CheckStatus_OkImplCopyWith<$Res> {
  __$$CheckStatus_OkImplCopyWithImpl(
    _$CheckStatus_OkImpl _value,
    $Res Function(_$CheckStatus_OkImpl) _then,
  ) : super(_value, _then);

  /// Create a copy of CheckStatus
  /// with the given fields replaced by the non-null parameter values.
}

/// @nodoc

class _$CheckStatus_OkImpl extends CheckStatus_Ok {
  const _$CheckStatus_OkImpl() : super._();

  @override
  String toString() {
    return 'CheckStatus.ok()';
  }

  @override
  bool operator ==(Object other) {
    return identical(this, other) ||
        (other.runtimeType == runtimeType && other is _$CheckStatus_OkImpl);
  }

  @override
  int get hashCode => runtimeType.hashCode;

  @override
  @optionalTypeArgs
  TResult when<TResult extends Object?>({
    required TResult Function() ok,
    required TResult Function(String field0) warn,
    required TResult Function(String field0) fail,
  }) {
    return ok();
  }

  @override
  @optionalTypeArgs
  TResult? whenOrNull<TResult extends Object?>({
    TResult? Function()? ok,
    TResult? Function(String field0)? warn,
    TResult? Function(String field0)? fail,
  }) {
    return ok?.call();
  }

  @override
  @optionalTypeArgs
  TResult maybeWhen<TResult extends Object?>({
    TResult Function()? ok,
    TResult Function(String field0)? warn,
    TResult Function(String field0)? fail,
    required TResult orElse(),
  }) {
    if (ok != null) {
      return ok();
    }
    return orElse();
  }

  @override
  @optionalTypeArgs
  TResult map<TResult extends Object?>({
    required TResult Function(CheckStatus_Ok value) ok,
    required TResult Function(CheckStatus_Warn value) warn,
    required TResult Function(CheckStatus_Fail value) fail,
  }) {
    return ok(this);
  }

  @override
  @optionalTypeArgs
  TResult? mapOrNull<TResult extends Object?>({
    TResult? Function(CheckStatus_Ok value)? ok,
    TResult? Function(CheckStatus_Warn value)? warn,
    TResult? Function(CheckStatus_Fail value)? fail,
  }) {
    return ok?.call(this);
  }

  @override
  @optionalTypeArgs
  TResult maybeMap<TResult extends Object?>({
    TResult Function(CheckStatus_Ok value)? ok,
    TResult Function(CheckStatus_Warn value)? warn,
    TResult Function(CheckStatus_Fail value)? fail,
    required TResult orElse(),
  }) {
    if (ok != null) {
      return ok(this);
    }
    return orElse();
  }
}

abstract class CheckStatus_Ok extends CheckStatus {
  const factory CheckStatus_Ok() = _$CheckStatus_OkImpl;
  const CheckStatus_Ok._() : super._();
}

/// @nodoc
abstract class _$$CheckStatus_WarnImplCopyWith<$Res> {
  factory _$$CheckStatus_WarnImplCopyWith(
    _$CheckStatus_WarnImpl value,
    $Res Function(_$CheckStatus_WarnImpl) then,
  ) = __$$CheckStatus_WarnImplCopyWithImpl<$Res>;
  @useResult
  $Res call({String field0});
}

/// @nodoc
class __$$CheckStatus_WarnImplCopyWithImpl<$Res>
    extends _$CheckStatusCopyWithImpl<$Res, _$CheckStatus_WarnImpl>
    implements _$$CheckStatus_WarnImplCopyWith<$Res> {
  __$$CheckStatus_WarnImplCopyWithImpl(
    _$CheckStatus_WarnImpl _value,
    $Res Function(_$CheckStatus_WarnImpl) _then,
  ) : super(_value, _then);

  /// Create a copy of CheckStatus
  /// with the given fields replaced by the non-null parameter values.
  @pragma('vm:prefer-inline')
  @override
  $Res call({Object? field0 = null}) {
    return _then(
      _$CheckStatus_WarnImpl(
        null == field0
            ? _value.field0
            : field0 // ignore: cast_nullable_to_non_nullable
                  as String,
      ),
    );
  }
}

/// @nodoc

class _$CheckStatus_WarnImpl extends CheckStatus_Warn {
  const _$CheckStatus_WarnImpl(this.field0) : super._();

  @override
  final String field0;

  @override
  String toString() {
    return 'CheckStatus.warn(field0: $field0)';
  }

  @override
  bool operator ==(Object other) {
    return identical(this, other) ||
        (other.runtimeType == runtimeType &&
            other is _$CheckStatus_WarnImpl &&
            (identical(other.field0, field0) || other.field0 == field0));
  }

  @override
  int get hashCode => Object.hash(runtimeType, field0);

  /// Create a copy of CheckStatus
  /// with the given fields replaced by the non-null parameter values.
  @JsonKey(includeFromJson: false, includeToJson: false)
  @override
  @pragma('vm:prefer-inline')
  _$$CheckStatus_WarnImplCopyWith<_$CheckStatus_WarnImpl> get copyWith =>
      __$$CheckStatus_WarnImplCopyWithImpl<_$CheckStatus_WarnImpl>(
        this,
        _$identity,
      );

  @override
  @optionalTypeArgs
  TResult when<TResult extends Object?>({
    required TResult Function() ok,
    required TResult Function(String field0) warn,
    required TResult Function(String field0) fail,
  }) {
    return warn(field0);
  }

  @override
  @optionalTypeArgs
  TResult? whenOrNull<TResult extends Object?>({
    TResult? Function()? ok,
    TResult? Function(String field0)? warn,
    TResult? Function(String field0)? fail,
  }) {
    return warn?.call(field0);
  }

  @override
  @optionalTypeArgs
  TResult maybeWhen<TResult extends Object?>({
    TResult Function()? ok,
    TResult Function(String field0)? warn,
    TResult Function(String field0)? fail,
    required TResult orElse(),
  }) {
    if (warn != null) {
      return warn(field0);
    }
    return orElse();
  }

  @override
  @optionalTypeArgs
  TResult map<TResult extends Object?>({
    required TResult Function(CheckStatus_Ok value) ok,
    required TResult Function(CheckStatus_Warn value) warn,
    required TResult Function(CheckStatus_Fail value) fail,
  }) {
    return warn(this);
  }

  @override
  @optionalTypeArgs
  TResult? mapOrNull<TResult extends Object?>({
    TResult? Function(CheckStatus_Ok value)? ok,
    TResult? Function(CheckStatus_Warn value)? warn,
    TResult? Function(CheckStatus_Fail value)? fail,
  }) {
    return warn?.call(this);
  }

  @override
  @optionalTypeArgs
  TResult maybeMap<TResult extends Object?>({
    TResult Function(CheckStatus_Ok value)? ok,
    TResult Function(CheckStatus_Warn value)? warn,
    TResult Function(CheckStatus_Fail value)? fail,
    required TResult orElse(),
  }) {
    if (warn != null) {
      return warn(this);
    }
    return orElse();
  }
}

abstract class CheckStatus_Warn extends CheckStatus {
  const factory CheckStatus_Warn(final String field0) = _$CheckStatus_WarnImpl;
  const CheckStatus_Warn._() : super._();

  String get field0;

  /// Create a copy of CheckStatus
  /// with the given fields replaced by the non-null parameter values.
  @JsonKey(includeFromJson: false, includeToJson: false)
  _$$CheckStatus_WarnImplCopyWith<_$CheckStatus_WarnImpl> get copyWith =>
      throw _privateConstructorUsedError;
}

/// @nodoc
abstract class _$$CheckStatus_FailImplCopyWith<$Res> {
  factory _$$CheckStatus_FailImplCopyWith(
    _$CheckStatus_FailImpl value,
    $Res Function(_$CheckStatus_FailImpl) then,
  ) = __$$CheckStatus_FailImplCopyWithImpl<$Res>;
  @useResult
  $Res call({String field0});
}

/// @nodoc
class __$$CheckStatus_FailImplCopyWithImpl<$Res>
    extends _$CheckStatusCopyWithImpl<$Res, _$CheckStatus_FailImpl>
    implements _$$CheckStatus_FailImplCopyWith<$Res> {
  __$$CheckStatus_FailImplCopyWithImpl(
    _$CheckStatus_FailImpl _value,
    $Res Function(_$CheckStatus_FailImpl) _then,
  ) : super(_value, _then);

  /// Create a copy of CheckStatus
  /// with the given fields replaced by the non-null parameter values.
  @pragma('vm:prefer-inline')
  @override
  $Res call({Object? field0 = null}) {
    return _then(
      _$CheckStatus_FailImpl(
        null == field0
            ? _value.field0
            : field0 // ignore: cast_nullable_to_non_nullable
                  as String,
      ),
    );
  }
}

/// @nodoc

class _$CheckStatus_FailImpl extends CheckStatus_Fail {
  const _$CheckStatus_FailImpl(this.field0) : super._();

  @override
  final String field0;

  @override
  String toString() {
    return 'CheckStatus.fail(field0: $field0)';
  }

  @override
  bool operator ==(Object other) {
    return identical(this, other) ||
        (other.runtimeType == runtimeType &&
            other is _$CheckStatus_FailImpl &&
            (identical(other.field0, field0) || other.field0 == field0));
  }

  @override
  int get hashCode => Object.hash(runtimeType, field0);

  /// Create a copy of CheckStatus
  /// with the given fields replaced by the non-null parameter values.
  @JsonKey(includeFromJson: false, includeToJson: false)
  @override
  @pragma('vm:prefer-inline')
  _$$CheckStatus_FailImplCopyWith<_$CheckStatus_FailImpl> get copyWith =>
      __$$CheckStatus_FailImplCopyWithImpl<_$CheckStatus_FailImpl>(
        this,
        _$identity,
      );

  @override
  @optionalTypeArgs
  TResult when<TResult extends Object?>({
    required TResult Function() ok,
    required TResult Function(String field0) warn,
    required TResult Function(String field0) fail,
  }) {
    return fail(field0);
  }

  @override
  @optionalTypeArgs
  TResult? whenOrNull<TResult extends Object?>({
    TResult? Function()? ok,
    TResult? Function(String field0)? warn,
    TResult? Function(String field0)? fail,
  }) {
    return fail?.call(field0);
  }

  @override
  @optionalTypeArgs
  TResult maybeWhen<TResult extends Object?>({
    TResult Function()? ok,
    TResult Function(String field0)? warn,
    TResult Function(String field0)? fail,
    required TResult orElse(),
  }) {
    if (fail != null) {
      return fail(field0);
    }
    return orElse();
  }

  @override
  @optionalTypeArgs
  TResult map<TResult extends Object?>({
    required TResult Function(CheckStatus_Ok value) ok,
    required TResult Function(CheckStatus_Warn value) warn,
    required TResult Function(CheckStatus_Fail value) fail,
  }) {
    return fail(this);
  }

  @override
  @optionalTypeArgs
  TResult? mapOrNull<TResult extends Object?>({
    TResult? Function(CheckStatus_Ok value)? ok,
    TResult? Function(CheckStatus_Warn value)? warn,
    TResult? Function(CheckStatus_Fail value)? fail,
  }) {
    return fail?.call(this);
  }

  @override
  @optionalTypeArgs
  TResult maybeMap<TResult extends Object?>({
    TResult Function(CheckStatus_Ok value)? ok,
    TResult Function(CheckStatus_Warn value)? warn,
    TResult Function(CheckStatus_Fail value)? fail,
    required TResult orElse(),
  }) {
    if (fail != null) {
      return fail(this);
    }
    return orElse();
  }
}

abstract class CheckStatus_Fail extends CheckStatus {
  const factory CheckStatus_Fail(final String field0) = _$CheckStatus_FailImpl;
  const CheckStatus_Fail._() : super._();

  String get field0;

  /// Create a copy of CheckStatus
  /// with the given fields replaced by the non-null parameter values.
  @JsonKey(includeFromJson: false, includeToJson: false)
  _$$CheckStatus_FailImplCopyWith<_$CheckStatus_FailImpl> get copyWith =>
      throw _privateConstructorUsedError;
}
