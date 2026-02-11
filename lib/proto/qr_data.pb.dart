// This is a generated file - do not edit.
//
// Generated from lib/proto/qr_data.proto.

// @dart = 3.3

// ignore_for_file: annotate_overrides, camel_case_types, comment_references
// ignore_for_file: constant_identifier_names
// ignore_for_file: curly_braces_in_flow_control_structures
// ignore_for_file: deprecated_member_use_from_same_package, library_prefixes
// ignore_for_file: non_constant_identifier_names, prefer_relative_imports

import 'dart:core' as $core;

import 'package:protobuf/protobuf.dart' as $pb;

export 'package:protobuf/protobuf.dart' show GeneratedMessageGenericExtensions;

class QRData extends $pb.GeneratedMessage {
  factory QRData({
    $core.String? rowId,
    $core.String? itemCode,
    $core.String? varianceName,
    $core.String? uom,
    $core.String? qty,
    $core.String? price,
    $core.String? pkdDate,
    $core.String? expDate,
    $core.bool? isBirthdayCake,
    $core.String? cakeId,
  }) {
    final result = create();
    if (rowId != null) result.rowId = rowId;
    if (itemCode != null) result.itemCode = itemCode;
    if (varianceName != null) result.varianceName = varianceName;
    if (uom != null) result.uom = uom;
    if (qty != null) result.qty = qty;
    if (price != null) result.price = price;
    if (pkdDate != null) result.pkdDate = pkdDate;
    if (expDate != null) result.expDate = expDate;
    if (isBirthdayCake != null) result.isBirthdayCake = isBirthdayCake;
    if (cakeId != null) result.cakeId = cakeId;
    return result;
  }

  QRData._();

  factory QRData.fromBuffer($core.List<$core.int> data,
          [$pb.ExtensionRegistry registry = $pb.ExtensionRegistry.EMPTY]) =>
      create()..mergeFromBuffer(data, registry);
  factory QRData.fromJson($core.String json,
          [$pb.ExtensionRegistry registry = $pb.ExtensionRegistry.EMPTY]) =>
      create()..mergeFromJson(json, registry);

  static final $pb.BuilderInfo _i = $pb.BuilderInfo(
      _omitMessageNames ? '' : 'QRData',
      createEmptyInstance: create)
    ..aOS(1, _omitFieldNames ? '' : 'rowId', protoName: 'rowId')
    ..aOS(2, _omitFieldNames ? '' : 'itemCode', protoName: 'itemCode')
    ..aOS(3, _omitFieldNames ? '' : 'varianceName', protoName: 'varianceName')
    ..aOS(4, _omitFieldNames ? '' : 'uom')
    ..aOS(5, _omitFieldNames ? '' : 'qty')
    ..aOS(6, _omitFieldNames ? '' : 'price')
    ..aOS(7, _omitFieldNames ? '' : 'pkdDate', protoName: 'pkdDate')
    ..aOS(8, _omitFieldNames ? '' : 'expDate', protoName: 'expDate')
    ..aOB(9, _omitFieldNames ? '' : 'isBirthdayCake',
        protoName: 'isBirthdayCake')
    ..aOS(10, _omitFieldNames ? '' : 'cakeId', protoName: 'cakeId')
    ..hasRequiredFields = false;

  @$core.Deprecated('See https://github.com/google/protobuf.dart/issues/998.')
  QRData clone() => deepCopy();
  @$core.Deprecated('See https://github.com/google/protobuf.dart/issues/998.')
  QRData copyWith(void Function(QRData) updates) =>
      super.copyWith((message) => updates(message as QRData)) as QRData;

  @$core.override
  $pb.BuilderInfo get info_ => _i;

  @$core.pragma('dart2js:noInline')
  static QRData create() => QRData._();
  @$core.override
  QRData createEmptyInstance() => create();
  @$core.pragma('dart2js:noInline')
  static QRData getDefault() =>
      _defaultInstance ??= $pb.GeneratedMessage.$_defaultFor<QRData>(create);
  static QRData? _defaultInstance;

  @$pb.TagNumber(1)
  $core.String get rowId => $_getSZ(0);
  @$pb.TagNumber(1)
  set rowId($core.String value) => $_setString(0, value);
  @$pb.TagNumber(1)
  $core.bool hasRowId() => $_has(0);
  @$pb.TagNumber(1)
  void clearRowId() => $_clearField(1);

  @$pb.TagNumber(2)
  $core.String get itemCode => $_getSZ(1);
  @$pb.TagNumber(2)
  set itemCode($core.String value) => $_setString(1, value);
  @$pb.TagNumber(2)
  $core.bool hasItemCode() => $_has(1);
  @$pb.TagNumber(2)
  void clearItemCode() => $_clearField(2);

  @$pb.TagNumber(3)
  $core.String get varianceName => $_getSZ(2);
  @$pb.TagNumber(3)
  set varianceName($core.String value) => $_setString(2, value);
  @$pb.TagNumber(3)
  $core.bool hasVarianceName() => $_has(2);
  @$pb.TagNumber(3)
  void clearVarianceName() => $_clearField(3);

  @$pb.TagNumber(4)
  $core.String get uom => $_getSZ(3);
  @$pb.TagNumber(4)
  set uom($core.String value) => $_setString(3, value);
  @$pb.TagNumber(4)
  $core.bool hasUom() => $_has(3);
  @$pb.TagNumber(4)
  void clearUom() => $_clearField(4);

  @$pb.TagNumber(5)
  $core.String get qty => $_getSZ(4);
  @$pb.TagNumber(5)
  set qty($core.String value) => $_setString(4, value);
  @$pb.TagNumber(5)
  $core.bool hasQty() => $_has(4);
  @$pb.TagNumber(5)
  void clearQty() => $_clearField(5);

  @$pb.TagNumber(6)
  $core.String get price => $_getSZ(5);
  @$pb.TagNumber(6)
  set price($core.String value) => $_setString(5, value);
  @$pb.TagNumber(6)
  $core.bool hasPrice() => $_has(5);
  @$pb.TagNumber(6)
  void clearPrice() => $_clearField(6);

  @$pb.TagNumber(7)
  $core.String get pkdDate => $_getSZ(6);
  @$pb.TagNumber(7)
  set pkdDate($core.String value) => $_setString(6, value);
  @$pb.TagNumber(7)
  $core.bool hasPkdDate() => $_has(6);
  @$pb.TagNumber(7)
  void clearPkdDate() => $_clearField(7);

  @$pb.TagNumber(8)
  $core.String get expDate => $_getSZ(7);
  @$pb.TagNumber(8)
  set expDate($core.String value) => $_setString(7, value);
  @$pb.TagNumber(8)
  $core.bool hasExpDate() => $_has(7);
  @$pb.TagNumber(8)
  void clearExpDate() => $_clearField(8);

  @$pb.TagNumber(9)
  $core.bool get isBirthdayCake => $_getBF(8);
  @$pb.TagNumber(9)
  set isBirthdayCake($core.bool value) => $_setBool(8, value);
  @$pb.TagNumber(9)
  $core.bool hasIsBirthdayCake() => $_has(8);
  @$pb.TagNumber(9)
  void clearIsBirthdayCake() => $_clearField(9);

  @$pb.TagNumber(10)
  $core.String get cakeId => $_getSZ(9);
  @$pb.TagNumber(10)
  set cakeId($core.String value) => $_setString(9, value);
  @$pb.TagNumber(10)
  $core.bool hasCakeId() => $_has(9);
  @$pb.TagNumber(10)
  void clearCakeId() => $_clearField(10);
}

const $core.bool _omitFieldNames =
    $core.bool.fromEnvironment('protobuf.omit_field_names');
const $core.bool _omitMessageNames =
    $core.bool.fromEnvironment('protobuf.omit_message_names');
