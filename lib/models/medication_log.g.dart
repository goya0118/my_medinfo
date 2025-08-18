// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'medication_log.dart';

// **************************************************************************
// IsarCollectionGenerator
// **************************************************************************

// coverage:ignore-file
// ignore_for_file: duplicate_ignore, non_constant_identifier_names, constant_identifier_names, invalid_use_of_protected_member, unnecessary_cast, prefer_const_constructors, lines_longer_than_80_chars, require_trailing_commas, inference_failure_on_function_invocation, unnecessary_parenthesis, unnecessary_raw_strings, unnecessary_null_checks, join_return_with_assignment, prefer_final_locals, avoid_js_rounded_ints, avoid_positional_boolean_parameters, always_specify_types

extension GetMedicationLogCollection on Isar {
  IsarCollection<MedicationLog> get medicationLogs => this.collection();
}

const MedicationLogSchema = CollectionSchema(
  name: r'MedicationLog',
  id: 1536858489241207630,
  properties: {
    r'drugName': PropertySchema(
      id: 0,
      name: r'drugName',
      type: IsarType.string,
    ),
    r'quantity': PropertySchema(
      id: 1,
      name: r'quantity',
      type: IsarType.long,
    ),
    r'takenAt': PropertySchema(
      id: 2,
      name: r'takenAt',
      type: IsarType.dateTime,
    )
  },
  estimateSize: _medicationLogEstimateSize,
  serialize: _medicationLogSerialize,
  deserialize: _medicationLogDeserialize,
  deserializeProp: _medicationLogDeserializeProp,
  idName: r'id',
  indexes: {
    r'drugName': IndexSchema(
      id: 2608149026769644500,
      name: r'drugName',
      unique: false,
      replace: false,
      properties: [
        IndexPropertySchema(
          name: r'drugName',
          type: IndexType.hash,
          caseSensitive: true,
        )
      ],
    ),
    r'takenAt': IndexSchema(
      id: 3100870333600442526,
      name: r'takenAt',
      unique: false,
      replace: false,
      properties: [
        IndexPropertySchema(
          name: r'takenAt',
          type: IndexType.value,
          caseSensitive: false,
        )
      ],
    )
  },
  links: {},
  embeddedSchemas: {},
  getId: _medicationLogGetId,
  getLinks: _medicationLogGetLinks,
  attach: _medicationLogAttach,
  version: '3.1.0+1',
);

int _medicationLogEstimateSize(
  MedicationLog object,
  List<int> offsets,
  Map<Type, List<int>> allOffsets,
) {
  var bytesCount = offsets.last;
  bytesCount += 3 + object.drugName.length * 3;
  return bytesCount;
}

void _medicationLogSerialize(
  MedicationLog object,
  IsarWriter writer,
  List<int> offsets,
  Map<Type, List<int>> allOffsets,
) {
  writer.writeString(offsets[0], object.drugName);
  writer.writeLong(offsets[1], object.quantity);
  writer.writeDateTime(offsets[2], object.takenAt);
}

MedicationLog _medicationLogDeserialize(
  Id id,
  IsarReader reader,
  List<int> offsets,
  Map<Type, List<int>> allOffsets,
) {
  final object = MedicationLog(
    drugName: reader.readString(offsets[0]),
    quantity: reader.readLongOrNull(offsets[1]) ?? 1,
    takenAt: reader.readDateTime(offsets[2]),
  );
  object.id = id;
  return object;
}

P _medicationLogDeserializeProp<P>(
  IsarReader reader,
  int propertyId,
  int offset,
  Map<Type, List<int>> allOffsets,
) {
  switch (propertyId) {
    case 0:
      return (reader.readString(offset)) as P;
    case 1:
      return (reader.readLongOrNull(offset) ?? 1) as P;
    case 2:
      return (reader.readDateTime(offset)) as P;
    default:
      throw IsarError('Unknown property with id $propertyId');
  }
}

Id _medicationLogGetId(MedicationLog object) {
  return object.id;
}

List<IsarLinkBase<dynamic>> _medicationLogGetLinks(MedicationLog object) {
  return [];
}

void _medicationLogAttach(
    IsarCollection<dynamic> col, Id id, MedicationLog object) {
  object.id = id;
}

extension MedicationLogQueryWhereSort
    on QueryBuilder<MedicationLog, MedicationLog, QWhere> {
  QueryBuilder<MedicationLog, MedicationLog, QAfterWhere> anyId() {
    return QueryBuilder.apply(this, (query) {
      return query.addWhereClause(const IdWhereClause.any());
    });
  }

  QueryBuilder<MedicationLog, MedicationLog, QAfterWhere> anyTakenAt() {
    return QueryBuilder.apply(this, (query) {
      return query.addWhereClause(
        const IndexWhereClause.any(indexName: r'takenAt'),
      );
    });
  }
}

extension MedicationLogQueryWhere
    on QueryBuilder<MedicationLog, MedicationLog, QWhereClause> {
  QueryBuilder<MedicationLog, MedicationLog, QAfterWhereClause> idEqualTo(
      Id id) {
    return QueryBuilder.apply(this, (query) {
      return query.addWhereClause(IdWhereClause.between(
        lower: id,
        upper: id,
      ));
    });
  }

  QueryBuilder<MedicationLog, MedicationLog, QAfterWhereClause> idNotEqualTo(
      Id id) {
    return QueryBuilder.apply(this, (query) {
      if (query.whereSort == Sort.asc) {
        return query
            .addWhereClause(
              IdWhereClause.lessThan(upper: id, includeUpper: false),
            )
            .addWhereClause(
              IdWhereClause.greaterThan(lower: id, includeLower: false),
            );
      } else {
        return query
            .addWhereClause(
              IdWhereClause.greaterThan(lower: id, includeLower: false),
            )
            .addWhereClause(
              IdWhereClause.lessThan(upper: id, includeUpper: false),
            );
      }
    });
  }

  QueryBuilder<MedicationLog, MedicationLog, QAfterWhereClause> idGreaterThan(
      Id id,
      {bool include = false}) {
    return QueryBuilder.apply(this, (query) {
      return query.addWhereClause(
        IdWhereClause.greaterThan(lower: id, includeLower: include),
      );
    });
  }

  QueryBuilder<MedicationLog, MedicationLog, QAfterWhereClause> idLessThan(
      Id id,
      {bool include = false}) {
    return QueryBuilder.apply(this, (query) {
      return query.addWhereClause(
        IdWhereClause.lessThan(upper: id, includeUpper: include),
      );
    });
  }

  QueryBuilder<MedicationLog, MedicationLog, QAfterWhereClause> idBetween(
    Id lowerId,
    Id upperId, {
    bool includeLower = true,
    bool includeUpper = true,
  }) {
    return QueryBuilder.apply(this, (query) {
      return query.addWhereClause(IdWhereClause.between(
        lower: lowerId,
        includeLower: includeLower,
        upper: upperId,
        includeUpper: includeUpper,
      ));
    });
  }

  QueryBuilder<MedicationLog, MedicationLog, QAfterWhereClause> drugNameEqualTo(
      String drugName) {
    return QueryBuilder.apply(this, (query) {
      return query.addWhereClause(IndexWhereClause.equalTo(
        indexName: r'drugName',
        value: [drugName],
      ));
    });
  }

  QueryBuilder<MedicationLog, MedicationLog, QAfterWhereClause>
      drugNameNotEqualTo(String drugName) {
    return QueryBuilder.apply(this, (query) {
      if (query.whereSort == Sort.asc) {
        return query
            .addWhereClause(IndexWhereClause.between(
              indexName: r'drugName',
              lower: [],
              upper: [drugName],
              includeUpper: false,
            ))
            .addWhereClause(IndexWhereClause.between(
              indexName: r'drugName',
              lower: [drugName],
              includeLower: false,
              upper: [],
            ));
      } else {
        return query
            .addWhereClause(IndexWhereClause.between(
              indexName: r'drugName',
              lower: [drugName],
              includeLower: false,
              upper: [],
            ))
            .addWhereClause(IndexWhereClause.between(
              indexName: r'drugName',
              lower: [],
              upper: [drugName],
              includeUpper: false,
            ));
      }
    });
  }

  QueryBuilder<MedicationLog, MedicationLog, QAfterWhereClause> takenAtEqualTo(
      DateTime takenAt) {
    return QueryBuilder.apply(this, (query) {
      return query.addWhereClause(IndexWhereClause.equalTo(
        indexName: r'takenAt',
        value: [takenAt],
      ));
    });
  }

  QueryBuilder<MedicationLog, MedicationLog, QAfterWhereClause>
      takenAtNotEqualTo(DateTime takenAt) {
    return QueryBuilder.apply(this, (query) {
      if (query.whereSort == Sort.asc) {
        return query
            .addWhereClause(IndexWhereClause.between(
              indexName: r'takenAt',
              lower: [],
              upper: [takenAt],
              includeUpper: false,
            ))
            .addWhereClause(IndexWhereClause.between(
              indexName: r'takenAt',
              lower: [takenAt],
              includeLower: false,
              upper: [],
            ));
      } else {
        return query
            .addWhereClause(IndexWhereClause.between(
              indexName: r'takenAt',
              lower: [takenAt],
              includeLower: false,
              upper: [],
            ))
            .addWhereClause(IndexWhereClause.between(
              indexName: r'takenAt',
              lower: [],
              upper: [takenAt],
              includeUpper: false,
            ));
      }
    });
  }

  QueryBuilder<MedicationLog, MedicationLog, QAfterWhereClause>
      takenAtGreaterThan(
    DateTime takenAt, {
    bool include = false,
  }) {
    return QueryBuilder.apply(this, (query) {
      return query.addWhereClause(IndexWhereClause.between(
        indexName: r'takenAt',
        lower: [takenAt],
        includeLower: include,
        upper: [],
      ));
    });
  }

  QueryBuilder<MedicationLog, MedicationLog, QAfterWhereClause> takenAtLessThan(
    DateTime takenAt, {
    bool include = false,
  }) {
    return QueryBuilder.apply(this, (query) {
      return query.addWhereClause(IndexWhereClause.between(
        indexName: r'takenAt',
        lower: [],
        upper: [takenAt],
        includeUpper: include,
      ));
    });
  }

  QueryBuilder<MedicationLog, MedicationLog, QAfterWhereClause> takenAtBetween(
    DateTime lowerTakenAt,
    DateTime upperTakenAt, {
    bool includeLower = true,
    bool includeUpper = true,
  }) {
    return QueryBuilder.apply(this, (query) {
      return query.addWhereClause(IndexWhereClause.between(
        indexName: r'takenAt',
        lower: [lowerTakenAt],
        includeLower: includeLower,
        upper: [upperTakenAt],
        includeUpper: includeUpper,
      ));
    });
  }
}

extension MedicationLogQueryFilter
    on QueryBuilder<MedicationLog, MedicationLog, QFilterCondition> {
  QueryBuilder<MedicationLog, MedicationLog, QAfterFilterCondition>
      drugNameEqualTo(
    String value, {
    bool caseSensitive = true,
  }) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(FilterCondition.equalTo(
        property: r'drugName',
        value: value,
        caseSensitive: caseSensitive,
      ));
    });
  }

  QueryBuilder<MedicationLog, MedicationLog, QAfterFilterCondition>
      drugNameGreaterThan(
    String value, {
    bool include = false,
    bool caseSensitive = true,
  }) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(FilterCondition.greaterThan(
        include: include,
        property: r'drugName',
        value: value,
        caseSensitive: caseSensitive,
      ));
    });
  }

  QueryBuilder<MedicationLog, MedicationLog, QAfterFilterCondition>
      drugNameLessThan(
    String value, {
    bool include = false,
    bool caseSensitive = true,
  }) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(FilterCondition.lessThan(
        include: include,
        property: r'drugName',
        value: value,
        caseSensitive: caseSensitive,
      ));
    });
  }

  QueryBuilder<MedicationLog, MedicationLog, QAfterFilterCondition>
      drugNameBetween(
    String lower,
    String upper, {
    bool includeLower = true,
    bool includeUpper = true,
    bool caseSensitive = true,
  }) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(FilterCondition.between(
        property: r'drugName',
        lower: lower,
        includeLower: includeLower,
        upper: upper,
        includeUpper: includeUpper,
        caseSensitive: caseSensitive,
      ));
    });
  }

  QueryBuilder<MedicationLog, MedicationLog, QAfterFilterCondition>
      drugNameStartsWith(
    String value, {
    bool caseSensitive = true,
  }) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(FilterCondition.startsWith(
        property: r'drugName',
        value: value,
        caseSensitive: caseSensitive,
      ));
    });
  }

  QueryBuilder<MedicationLog, MedicationLog, QAfterFilterCondition>
      drugNameEndsWith(
    String value, {
    bool caseSensitive = true,
  }) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(FilterCondition.endsWith(
        property: r'drugName',
        value: value,
        caseSensitive: caseSensitive,
      ));
    });
  }

  QueryBuilder<MedicationLog, MedicationLog, QAfterFilterCondition>
      drugNameContains(String value, {bool caseSensitive = true}) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(FilterCondition.contains(
        property: r'drugName',
        value: value,
        caseSensitive: caseSensitive,
      ));
    });
  }

  QueryBuilder<MedicationLog, MedicationLog, QAfterFilterCondition>
      drugNameMatches(String pattern, {bool caseSensitive = true}) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(FilterCondition.matches(
        property: r'drugName',
        wildcard: pattern,
        caseSensitive: caseSensitive,
      ));
    });
  }

  QueryBuilder<MedicationLog, MedicationLog, QAfterFilterCondition>
      drugNameIsEmpty() {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(FilterCondition.equalTo(
        property: r'drugName',
        value: '',
      ));
    });
  }

  QueryBuilder<MedicationLog, MedicationLog, QAfterFilterCondition>
      drugNameIsNotEmpty() {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(FilterCondition.greaterThan(
        property: r'drugName',
        value: '',
      ));
    });
  }

  QueryBuilder<MedicationLog, MedicationLog, QAfterFilterCondition> idEqualTo(
      Id value) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(FilterCondition.equalTo(
        property: r'id',
        value: value,
      ));
    });
  }

  QueryBuilder<MedicationLog, MedicationLog, QAfterFilterCondition>
      idGreaterThan(
    Id value, {
    bool include = false,
  }) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(FilterCondition.greaterThan(
        include: include,
        property: r'id',
        value: value,
      ));
    });
  }

  QueryBuilder<MedicationLog, MedicationLog, QAfterFilterCondition> idLessThan(
    Id value, {
    bool include = false,
  }) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(FilterCondition.lessThan(
        include: include,
        property: r'id',
        value: value,
      ));
    });
  }

  QueryBuilder<MedicationLog, MedicationLog, QAfterFilterCondition> idBetween(
    Id lower,
    Id upper, {
    bool includeLower = true,
    bool includeUpper = true,
  }) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(FilterCondition.between(
        property: r'id',
        lower: lower,
        includeLower: includeLower,
        upper: upper,
        includeUpper: includeUpper,
      ));
    });
  }

  QueryBuilder<MedicationLog, MedicationLog, QAfterFilterCondition>
      quantityEqualTo(int value) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(FilterCondition.equalTo(
        property: r'quantity',
        value: value,
      ));
    });
  }

  QueryBuilder<MedicationLog, MedicationLog, QAfterFilterCondition>
      quantityGreaterThan(
    int value, {
    bool include = false,
  }) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(FilterCondition.greaterThan(
        include: include,
        property: r'quantity',
        value: value,
      ));
    });
  }

  QueryBuilder<MedicationLog, MedicationLog, QAfterFilterCondition>
      quantityLessThan(
    int value, {
    bool include = false,
  }) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(FilterCondition.lessThan(
        include: include,
        property: r'quantity',
        value: value,
      ));
    });
  }

  QueryBuilder<MedicationLog, MedicationLog, QAfterFilterCondition>
      quantityBetween(
    int lower,
    int upper, {
    bool includeLower = true,
    bool includeUpper = true,
  }) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(FilterCondition.between(
        property: r'quantity',
        lower: lower,
        includeLower: includeLower,
        upper: upper,
        includeUpper: includeUpper,
      ));
    });
  }

  QueryBuilder<MedicationLog, MedicationLog, QAfterFilterCondition>
      takenAtEqualTo(DateTime value) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(FilterCondition.equalTo(
        property: r'takenAt',
        value: value,
      ));
    });
  }

  QueryBuilder<MedicationLog, MedicationLog, QAfterFilterCondition>
      takenAtGreaterThan(
    DateTime value, {
    bool include = false,
  }) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(FilterCondition.greaterThan(
        include: include,
        property: r'takenAt',
        value: value,
      ));
    });
  }

  QueryBuilder<MedicationLog, MedicationLog, QAfterFilterCondition>
      takenAtLessThan(
    DateTime value, {
    bool include = false,
  }) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(FilterCondition.lessThan(
        include: include,
        property: r'takenAt',
        value: value,
      ));
    });
  }

  QueryBuilder<MedicationLog, MedicationLog, QAfterFilterCondition>
      takenAtBetween(
    DateTime lower,
    DateTime upper, {
    bool includeLower = true,
    bool includeUpper = true,
  }) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(FilterCondition.between(
        property: r'takenAt',
        lower: lower,
        includeLower: includeLower,
        upper: upper,
        includeUpper: includeUpper,
      ));
    });
  }
}

extension MedicationLogQueryObject
    on QueryBuilder<MedicationLog, MedicationLog, QFilterCondition> {}

extension MedicationLogQueryLinks
    on QueryBuilder<MedicationLog, MedicationLog, QFilterCondition> {}

extension MedicationLogQuerySortBy
    on QueryBuilder<MedicationLog, MedicationLog, QSortBy> {
  QueryBuilder<MedicationLog, MedicationLog, QAfterSortBy> sortByDrugName() {
    return QueryBuilder.apply(this, (query) {
      return query.addSortBy(r'drugName', Sort.asc);
    });
  }

  QueryBuilder<MedicationLog, MedicationLog, QAfterSortBy>
      sortByDrugNameDesc() {
    return QueryBuilder.apply(this, (query) {
      return query.addSortBy(r'drugName', Sort.desc);
    });
  }

  QueryBuilder<MedicationLog, MedicationLog, QAfterSortBy> sortByQuantity() {
    return QueryBuilder.apply(this, (query) {
      return query.addSortBy(r'quantity', Sort.asc);
    });
  }

  QueryBuilder<MedicationLog, MedicationLog, QAfterSortBy>
      sortByQuantityDesc() {
    return QueryBuilder.apply(this, (query) {
      return query.addSortBy(r'quantity', Sort.desc);
    });
  }

  QueryBuilder<MedicationLog, MedicationLog, QAfterSortBy> sortByTakenAt() {
    return QueryBuilder.apply(this, (query) {
      return query.addSortBy(r'takenAt', Sort.asc);
    });
  }

  QueryBuilder<MedicationLog, MedicationLog, QAfterSortBy> sortByTakenAtDesc() {
    return QueryBuilder.apply(this, (query) {
      return query.addSortBy(r'takenAt', Sort.desc);
    });
  }
}

extension MedicationLogQuerySortThenBy
    on QueryBuilder<MedicationLog, MedicationLog, QSortThenBy> {
  QueryBuilder<MedicationLog, MedicationLog, QAfterSortBy> thenByDrugName() {
    return QueryBuilder.apply(this, (query) {
      return query.addSortBy(r'drugName', Sort.asc);
    });
  }

  QueryBuilder<MedicationLog, MedicationLog, QAfterSortBy>
      thenByDrugNameDesc() {
    return QueryBuilder.apply(this, (query) {
      return query.addSortBy(r'drugName', Sort.desc);
    });
  }

  QueryBuilder<MedicationLog, MedicationLog, QAfterSortBy> thenById() {
    return QueryBuilder.apply(this, (query) {
      return query.addSortBy(r'id', Sort.asc);
    });
  }

  QueryBuilder<MedicationLog, MedicationLog, QAfterSortBy> thenByIdDesc() {
    return QueryBuilder.apply(this, (query) {
      return query.addSortBy(r'id', Sort.desc);
    });
  }

  QueryBuilder<MedicationLog, MedicationLog, QAfterSortBy> thenByQuantity() {
    return QueryBuilder.apply(this, (query) {
      return query.addSortBy(r'quantity', Sort.asc);
    });
  }

  QueryBuilder<MedicationLog, MedicationLog, QAfterSortBy>
      thenByQuantityDesc() {
    return QueryBuilder.apply(this, (query) {
      return query.addSortBy(r'quantity', Sort.desc);
    });
  }

  QueryBuilder<MedicationLog, MedicationLog, QAfterSortBy> thenByTakenAt() {
    return QueryBuilder.apply(this, (query) {
      return query.addSortBy(r'takenAt', Sort.asc);
    });
  }

  QueryBuilder<MedicationLog, MedicationLog, QAfterSortBy> thenByTakenAtDesc() {
    return QueryBuilder.apply(this, (query) {
      return query.addSortBy(r'takenAt', Sort.desc);
    });
  }
}

extension MedicationLogQueryWhereDistinct
    on QueryBuilder<MedicationLog, MedicationLog, QDistinct> {
  QueryBuilder<MedicationLog, MedicationLog, QDistinct> distinctByDrugName(
      {bool caseSensitive = true}) {
    return QueryBuilder.apply(this, (query) {
      return query.addDistinctBy(r'drugName', caseSensitive: caseSensitive);
    });
  }

  QueryBuilder<MedicationLog, MedicationLog, QDistinct> distinctByQuantity() {
    return QueryBuilder.apply(this, (query) {
      return query.addDistinctBy(r'quantity');
    });
  }

  QueryBuilder<MedicationLog, MedicationLog, QDistinct> distinctByTakenAt() {
    return QueryBuilder.apply(this, (query) {
      return query.addDistinctBy(r'takenAt');
    });
  }
}

extension MedicationLogQueryProperty
    on QueryBuilder<MedicationLog, MedicationLog, QQueryProperty> {
  QueryBuilder<MedicationLog, int, QQueryOperations> idProperty() {
    return QueryBuilder.apply(this, (query) {
      return query.addPropertyName(r'id');
    });
  }

  QueryBuilder<MedicationLog, String, QQueryOperations> drugNameProperty() {
    return QueryBuilder.apply(this, (query) {
      return query.addPropertyName(r'drugName');
    });
  }

  QueryBuilder<MedicationLog, int, QQueryOperations> quantityProperty() {
    return QueryBuilder.apply(this, (query) {
      return query.addPropertyName(r'quantity');
    });
  }

  QueryBuilder<MedicationLog, DateTime, QQueryOperations> takenAtProperty() {
    return QueryBuilder.apply(this, (query) {
      return query.addPropertyName(r'takenAt');
    });
  }
}
