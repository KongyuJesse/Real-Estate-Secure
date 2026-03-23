class CameroonRegionCatalog {
  const CameroonRegionCatalog({
    required this.name,
    required this.departments,
    this.code = '',
    this.capital = '',
  });

  final String code;
  final String name;
  final String capital;
  final List<CameroonDepartmentCatalog> departments;

  factory CameroonRegionCatalog.fromJson(Map<String, dynamic> json) {
    return CameroonRegionCatalog(
      code: json['code']?.toString() ?? '',
      name: json['name']?.toString() ?? '',
      capital: json['capital']?.toString() ?? '',
      departments: (json['departments'] as List? ?? const [])
          .map(
            (item) => CameroonDepartmentCatalog.fromJson(
              Map<String, dynamic>.from(item as Map),
            ),
          )
          .toList(growable: false),
    );
  }

  CameroonDepartmentCatalog? departmentNamed(String? value) {
    if (value == null) {
      return null;
    }
    final normalized = _normalizeLocationName(value);
    for (final department in departments) {
      if (_normalizeLocationName(department.name) == normalized ||
          _normalizeLocationName(department.code) == normalized) {
        return department;
      }
    }
    return null;
  }
}

class CameroonDepartmentCatalog {
  const CameroonDepartmentCatalog({
    required this.name,
    required this.cities,
    this.code = '',
  });

  final String code;
  final String name;
  final List<CameroonCityCatalog> cities;

  factory CameroonDepartmentCatalog.fromJson(Map<String, dynamic> json) {
    return CameroonDepartmentCatalog(
      code: json['code']?.toString() ?? '',
      name: json['name']?.toString() ?? '',
      cities: (json['cities'] as List? ?? const [])
          .map(
            (item) => CameroonCityCatalog.fromJson(
              Map<String, dynamic>.from(item as Map),
            ),
          )
          .toList(growable: false),
    );
  }

  CameroonCityCatalog? cityNamed(String? value) {
    if (value == null) {
      return null;
    }
    final normalized = _normalizeLocationName(value);
    for (final city in cities) {
      if (_normalizeLocationName(city.name) == normalized) {
        return city;
      }
    }
    return null;
  }
}

class CameroonCityCatalog {
  const CameroonCityCatalog({required this.name, this.districts = const []});

  final String name;
  final List<String> districts;

  factory CameroonCityCatalog.fromJson(Map<String, dynamic> json) {
    return CameroonCityCatalog(
      name: json['name']?.toString() ?? '',
      districts: (json['districts'] as List? ?? const [])
          .map((item) => item.toString())
          .toList(growable: false),
    );
  }
}

CameroonRegionCatalog? cameroonRegionNamed(String? value) =>
    cameroonRegionNamedInCatalog(cameroonLocationCatalog, value);

CameroonRegionCatalog? cameroonRegionNamedInCatalog(
  List<CameroonRegionCatalog> catalog,
  String? value,
) {
  if (value == null) {
    return null;
  }
  final normalized = _normalizeLocationName(value);
  for (final region in catalog) {
    if (_normalizeLocationName(region.name) == normalized ||
        _normalizeLocationName(region.code) == normalized) {
      return region;
    }
  }
  return null;
}

List<CameroonRegionCatalog> mergeCameroonLocationCatalogWithBackend(
  List<CameroonRegionCatalog> backendCatalog,
) {
  if (backendCatalog.isEmpty) {
    return cameroonLocationCatalog;
  }

  return backendCatalog
      .map((backendRegion) {
        final localRegion = cameroonRegionNamed(backendRegion.name);
        final mergedDepartments = backendRegion.departments
            .map((backendDepartment) {
              final localDepartment = localRegion?.departmentNamed(
                backendDepartment.name,
              );
              return CameroonDepartmentCatalog(
                code: backendDepartment.code,
                name: backendDepartment.name,
                cities: localDepartment?.cities ?? const [],
              );
            })
            .toList(growable: false);

        return CameroonRegionCatalog(
          code: backendRegion.code,
          name: backendRegion.name,
          capital: backendRegion.capital,
          departments: mergedDepartments,
        );
      })
      .toList(growable: false);
}

String _normalizeLocationName(String value) => value.trim().toLowerCase();

const cameroonLocationCatalog = <CameroonRegionCatalog>[
  CameroonRegionCatalog(
    name: 'Adamawa',
    departments: [
      CameroonDepartmentCatalog(
        name: 'Vina',
        cities: [
          CameroonCityCatalog(
            name: 'Ngaoundere',
            districts: ['Ngaoundere I', 'Ngaoundere II', 'Ngaoundere III'],
          ),
          CameroonCityCatalog(name: 'Belel', districts: ['Belel']),
          CameroonCityCatalog(name: 'Martap', districts: ['Martap']),
        ],
      ),
      CameroonDepartmentCatalog(
        name: 'Mayo-Banyo',
        cities: [
          CameroonCityCatalog(name: 'Banyo', districts: ['Banyo']),
          CameroonCityCatalog(name: 'Bankim', districts: ['Bankim']),
          CameroonCityCatalog(name: 'Mayo-Darle', districts: ['Mayo-Darle']),
        ],
      ),
      CameroonDepartmentCatalog(
        name: 'Mbere',
        cities: [
          CameroonCityCatalog(name: 'Meiganga', districts: ['Meiganga']),
          CameroonCityCatalog(name: 'Ngaoui', districts: ['Ngaoui']),
          CameroonCityCatalog(name: 'Djohong', districts: ['Djohong']),
        ],
      ),
    ],
  ),
  CameroonRegionCatalog(
    name: 'Centre',
    departments: [
      CameroonDepartmentCatalog(
        name: 'Mfoundi',
        cities: [
          CameroonCityCatalog(
            name: 'Yaounde',
            districts: [
              'Yaounde I',
              'Yaounde II',
              'Yaounde III',
              'Yaounde IV',
              'Yaounde V',
              'Yaounde VI',
              'Yaounde VII',
            ],
          ),
        ],
      ),
      CameroonDepartmentCatalog(
        name: 'Mefou-et-Afamba',
        cities: [
          CameroonCityCatalog(name: 'Mfou', districts: ['Mfou']),
          CameroonCityCatalog(name: 'Nkolafamba', districts: ['Nkolafamba']),
          CameroonCityCatalog(name: 'Soa', districts: ['Soa']),
        ],
      ),
      CameroonDepartmentCatalog(
        name: 'Nyong-et-Soo',
        cities: [
          CameroonCityCatalog(name: 'Mbalmayo', districts: ['Mbalmayo']),
          CameroonCityCatalog(name: 'Ngomedzap', districts: ['Ngomedzap']),
          CameroonCityCatalog(name: 'Dzeng', districts: ['Dzeng']),
        ],
      ),
    ],
  ),
  CameroonRegionCatalog(
    name: 'East',
    departments: [
      CameroonDepartmentCatalog(
        name: 'Lom-et-Djerem',
        cities: [
          CameroonCityCatalog(
            name: 'Bertoua',
            districts: ['Bertoua I', 'Bertoua II'],
          ),
          CameroonCityCatalog(name: 'Belabo', districts: ['Belabo']),
          CameroonCityCatalog(name: 'Ngoura', districts: ['Ngoura']),
        ],
      ),
      CameroonDepartmentCatalog(
        name: 'Kadey',
        cities: [
          CameroonCityCatalog(name: 'Batouri', districts: ['Batouri']),
          CameroonCityCatalog(name: 'Kette', districts: ['Kette']),
          CameroonCityCatalog(name: 'Kentzou', districts: ['Kentzou']),
        ],
      ),
      CameroonDepartmentCatalog(
        name: 'Haut-Nyong',
        cities: [
          CameroonCityCatalog(name: 'Abong-Mbang', districts: ['Abong-Mbang']),
          CameroonCityCatalog(name: 'Lomie', districts: ['Lomie']),
          CameroonCityCatalog(name: 'Messamena', districts: ['Messamena']),
        ],
      ),
    ],
  ),
  CameroonRegionCatalog(
    name: 'Far North',
    departments: [
      CameroonDepartmentCatalog(
        name: 'Diamare',
        cities: [
          CameroonCityCatalog(
            name: 'Maroua',
            districts: ['Maroua I', 'Maroua II', 'Maroua III'],
          ),
          CameroonCityCatalog(name: 'Bogo', districts: ['Bogo']),
          CameroonCityCatalog(name: 'Meri', districts: ['Meri']),
        ],
      ),
      CameroonDepartmentCatalog(
        name: 'Mayo-Sava',
        cities: [
          CameroonCityCatalog(name: 'Mora', districts: ['Mora']),
          CameroonCityCatalog(name: 'Kolofata', districts: ['Kolofata']),
          CameroonCityCatalog(name: 'Tokombere', districts: ['Tokombere']),
        ],
      ),
      CameroonDepartmentCatalog(
        name: 'Mayo-Kani',
        cities: [
          CameroonCityCatalog(name: 'Kaele', districts: ['Kaele']),
          CameroonCityCatalog(name: 'Guidiguis', districts: ['Guidiguis']),
          CameroonCityCatalog(name: 'Moutourwa', districts: ['Moutourwa']),
        ],
      ),
    ],
  ),
  CameroonRegionCatalog(
    name: 'Littoral',
    departments: [
      CameroonDepartmentCatalog(
        name: 'Wouri',
        cities: [
          CameroonCityCatalog(
            name: 'Douala',
            districts: [
              'Akwa',
              'Bonanjo',
              'Bonapriso',
              'Bonaberi',
              'Deido',
              'Japoma',
            ],
          ),
          CameroonCityCatalog(name: 'Manoka', districts: ['Manoka']),
          CameroonCityCatalog(name: 'Logbaba', districts: ['Logbaba']),
        ],
      ),
      CameroonDepartmentCatalog(
        name: 'Moungo',
        cities: [
          CameroonCityCatalog(
            name: 'Nkongsamba',
            districts: ['Nkongsamba I', 'Nkongsamba II', 'Nkongsamba III'],
          ),
          CameroonCityCatalog(name: 'Loum', districts: ['Loum']),
          CameroonCityCatalog(name: 'Manjo', districts: ['Manjo']),
        ],
      ),
      CameroonDepartmentCatalog(
        name: 'Sanaga-Maritime',
        cities: [
          CameroonCityCatalog(name: 'Edea', districts: ['Edea I', 'Edea II']),
          CameroonCityCatalog(name: 'Pouma', districts: ['Pouma']),
          CameroonCityCatalog(name: 'Dizangue', districts: ['Dizangue']),
        ],
      ),
    ],
  ),
  CameroonRegionCatalog(
    name: 'North',
    departments: [
      CameroonDepartmentCatalog(
        name: 'Benoue',
        cities: [
          CameroonCityCatalog(
            name: 'Garoua',
            districts: ['Garoua I', 'Garoua II', 'Garoua III'],
          ),
          CameroonCityCatalog(name: 'Bibemi', districts: ['Bibemi']),
          CameroonCityCatalog(name: 'Lagdo', districts: ['Lagdo']),
        ],
      ),
      CameroonDepartmentCatalog(
        name: 'Mayo-Louti',
        cities: [
          CameroonCityCatalog(name: 'Guider', districts: ['Guider']),
          CameroonCityCatalog(name: 'Figuil', districts: ['Figuil']),
          CameroonCityCatalog(name: 'Mayo-Oulo', districts: ['Mayo-Oulo']),
        ],
      ),
      CameroonDepartmentCatalog(
        name: 'Faro',
        cities: [
          CameroonCityCatalog(name: 'Poli', districts: ['Poli']),
          CameroonCityCatalog(name: 'Dembo', districts: ['Dembo']),
          CameroonCityCatalog(name: 'Beka', districts: ['Beka']),
        ],
      ),
    ],
  ),
  CameroonRegionCatalog(
    name: 'North-West',
    departments: [
      CameroonDepartmentCatalog(
        name: 'Mezam',
        cities: [
          CameroonCityCatalog(
            name: 'Bamenda',
            districts: ['Bamenda I', 'Bamenda II', 'Bamenda III'],
          ),
          CameroonCityCatalog(name: 'Bafut', districts: ['Bafut']),
          CameroonCityCatalog(name: 'Bali', districts: ['Bali']),
        ],
      ),
      CameroonDepartmentCatalog(
        name: 'Bui',
        cities: [
          CameroonCityCatalog(
            name: 'Kumbo',
            districts: ['Kumbo Central', 'Kumbo East', 'Kumbo West'],
          ),
          CameroonCityCatalog(name: 'Nkum', districts: ['Nkum']),
          CameroonCityCatalog(name: 'Oku', districts: ['Oku']),
        ],
      ),
      CameroonDepartmentCatalog(
        name: 'Donga-Mantung',
        cities: [
          CameroonCityCatalog(name: 'Nkambe', districts: ['Nkambe']),
          CameroonCityCatalog(name: 'Ako', districts: ['Ako']),
          CameroonCityCatalog(name: 'Nwa', districts: ['Nwa']),
        ],
      ),
    ],
  ),
  CameroonRegionCatalog(
    name: 'West',
    departments: [
      CameroonDepartmentCatalog(
        name: 'Mifi',
        cities: [
          CameroonCityCatalog(
            name: 'Bafoussam',
            districts: ['Bafoussam I', 'Bafoussam II', 'Bafoussam III'],
          ),
        ],
      ),
      CameroonDepartmentCatalog(
        name: 'Menoua',
        cities: [
          CameroonCityCatalog(name: 'Dschang', districts: ['Dschang']),
          CameroonCityCatalog(name: 'Santchou', districts: ['Santchou']),
          CameroonCityCatalog(
            name: 'Penka-Michel',
            districts: ['Penka-Michel'],
          ),
        ],
      ),
      CameroonDepartmentCatalog(
        name: 'Nde',
        cities: [
          CameroonCityCatalog(name: 'Bangangte', districts: ['Bangangte']),
          CameroonCityCatalog(name: 'Bazou', districts: ['Bazou']),
          CameroonCityCatalog(name: 'Tonga', districts: ['Tonga']),
        ],
      ),
    ],
  ),
  CameroonRegionCatalog(
    name: 'South',
    departments: [
      CameroonDepartmentCatalog(
        name: 'Mvila',
        cities: [
          CameroonCityCatalog(
            name: 'Ebolowa',
            districts: ['Ebolowa I', 'Ebolowa II'],
          ),
          CameroonCityCatalog(name: 'Mengong', districts: ['Mengong']),
          CameroonCityCatalog(name: 'Biwong-Bane', districts: ['Biwong-Bane']),
        ],
      ),
      CameroonDepartmentCatalog(
        name: 'Ocean',
        cities: [
          CameroonCityCatalog(
            name: 'Kribi',
            districts: ['Kribi I', 'Kribi II'],
          ),
          CameroonCityCatalog(name: 'Campo', districts: ['Campo']),
          CameroonCityCatalog(name: 'Akom II', districts: ['Akom II']),
        ],
      ),
      CameroonDepartmentCatalog(
        name: 'Dja-et-Lobo',
        cities: [
          CameroonCityCatalog(name: 'Sangmelima', districts: ['Sangmelima']),
          CameroonCityCatalog(name: 'Zoetele', districts: ['Zoetele']),
          CameroonCityCatalog(name: 'Meyomessi', districts: ['Meyomessi']),
        ],
      ),
    ],
  ),
  CameroonRegionCatalog(
    name: 'South-West',
    departments: [
      CameroonDepartmentCatalog(
        name: 'Fako',
        cities: [
          CameroonCityCatalog(
            name: 'Buea',
            districts: ['Molyko', 'Bonduma', 'Muea', 'Bova'],
          ),
          CameroonCityCatalog(
            name: 'Limbe',
            districts: ['Limbe I', 'Limbe II', 'Limbe III'],
          ),
          CameroonCityCatalog(name: 'Tiko', districts: ['Tiko', 'Mutengene']),
        ],
      ),
      CameroonDepartmentCatalog(
        name: 'Meme',
        cities: [
          CameroonCityCatalog(
            name: 'Kumba',
            districts: ['Kumba I', 'Kumba II', 'Kumba III'],
          ),
          CameroonCityCatalog(name: 'Mbonge', districts: ['Mbonge']),
          CameroonCityCatalog(name: 'Konye', districts: ['Konye']),
        ],
      ),
      CameroonDepartmentCatalog(
        name: 'Manyu',
        cities: [
          CameroonCityCatalog(name: 'Mamfe', districts: ['Mamfe']),
          CameroonCityCatalog(name: 'Eyumojock', districts: ['Eyumojock']),
          CameroonCityCatalog(name: 'Akwaya', districts: ['Akwaya']),
        ],
      ),
    ],
  ),
];
