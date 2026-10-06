import '../../models/study_clinical_snapshot.dart';

/// Provider-native output schema, independent of model/routing/auth selection.
class StudyCanonicalSchema {
  static const maxOutputTokens = 32768;
  static const marker = 'STUDY CANONICAL TRANSPORT v1';
  static bool applies(String prompt) => prompt.trimLeft().startsWith(marker);
  static Map<String, dynamic> string({List<String>? values, String? pattern}) =>
      {
        'type': 'string',
        if (values != null) 'enum': values,
        if (pattern != null) 'pattern': pattern,
      };
  static Map<String, dynamic> object(Map<String, dynamic> properties) => {
        'type': 'object',
        'properties': properties,
        'required': properties.keys.toList(),
        'additionalProperties': false,
      };
  static Map<String, dynamic> get label => {
        ...string(pattern: r'^[^0-9]+$'),
        'description':
            'Natural-language phrase WITHOUT any digit. Numbers and scientific symbols belong to separate shared items.'
      };
  static Map<String, dynamic> get id =>
      string(pattern: r'^[a-z][a-z0-9_]{0,159}$');
  static Map<String, dynamic> array(Object items) =>
      {'type': 'array', 'items': items};
  static Map<String, dynamic> get schema => array({
        'anyOf': [
          object({
            'type': string(values: ['title']),
            'id': id,
            'localization': object({'pt': label, 'es': label})
          }),
          object({
            'type': string(values: ['fact']),
            'id': id,
            'clinical': object({
              'section':
                  string(values: StudyClinicalSnapshot.headings.keys.toList()),
              'conceptId': id,
              'actionId': string(values: [
                'explain',
                'assess',
                'treat',
                'monitor',
                'avoid',
                'consider',
                'refer'
              ]),
              'polarity':
                  string(values: ['positive', 'negative', 'conditional']),
              'conditionIds': array(id),
              'items': array({
                'anyOf': [
                  object({
                    'id': id,
                    'kind': string(values: [
                      'concept',
                      'condition',
                      'action',
                      'monitoring',
                      'warning',
                      'relation'
                    ]),
                    'code': id,
                    'localization': object({'pt': label, 'es': label})
                  }),
                  object({
                    'id': id,
                    'kind': string(values: ['quantity', 'frequency']),
                    'amount': {'type': 'number'},
                    'upper': {
                      'type': ['number', 'null']
                    },
                    'operator': string(values: ['', '<', '>', '≤', '≥', '~']),
                    'unit': string(values: [
                      '',
                      'mg',
                      'g',
                      'mcg',
                      'µg',
                      'kg',
                      'mL',
                      'L',
                      'mmol',
                      'mEq',
                      'UI',
                      'U',
                      '%',
                      'h',
                      'min',
                      's',
                      'd',
                      'a',
                      'mo',
                      'mg/d',
                      'g/d',
                      'mg/kg',
                      'mg/kg/d',
                      'mg/kg/min',
                      'mcg/kg/min',
                      'mL/kg',
                      'mL/kg/h',
                      'mL/h',
                      'mmol/L',
                      'mEq/L',
                      'mg/dL',
                      'g/dL',
                      'mmHg',
                      'mL/min',
                      'mL/min/1.73m²',
                      'cm',
                      'mm',
                      'm²',
                      'bpm',
                      'rpm'
                    ]),
                  }),
                  object({
                    'id': id,
                    'kind': string(values: ['route']),
                    'value': string(values: [
                      'VO',
                      'IV',
                      'IM',
                      'SC',
                      'IO',
                      'IN',
                      'SL',
                      'EV',
                      'ID',
                      'IT',
                      'PR'
                    ])
                  }),
                  object({
                    'id': id,
                    'kind': string(values: ['neutral']),
                    'value': string(values: [
                      'HbA1c',
                      'P2Y12',
                      'COX1',
                      'COX2',
                      'B12',
                      'SpO2',
                      'PaO2',
                      'PaCO2',
                      'HCO3',
                      'Na+',
                      'K+',
                      'Cl-',
                      'H2O',
                      'pH',
                      'ECG',
                      'QTc',
                      'LDL',
                      'HDL',
                      'IgG',
                      'IgA',
                      'IgM',
                      'C3',
                      'C4',
                      'ACE2'
                    ])
                  }),
                ]
              }),
            })
          }),
          object({
            'type': string(values: ['end'])
          }),
        ]
      });

  static Map<String, dynamic> get generationConfig => {
        'responseMimeType': 'application/json',
        'responseJsonSchema': schema,
      };
}
