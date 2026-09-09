import 'dart:typed_data';

import 'package:quds_office_editor/quds_office_editor.dart';

/// UN-Habitat Al Tahreer Neighbourhood Profile (2026) as a live Word sample.
///
/// Cover, chapter openers, two-column body, and figures are real [WmlFrame],
/// [WmlSection.columnCount], paragraphs, tables, and photographs — not
/// full-page screenshots.
abstract final class AlTahreerSample {
  static const List<String> imageFiles = <String>[
    'cover_photo.jpg',
    'cover_map.jpg',
    'logo_unhabitat.png',
    'logo_japan.png',
    'logo_credits.jpg',
    'logo_back.png',
    'photo_overview.jpg',
    'photo_profile.jpg',
    'photo_unrwa.jpg',
    'photo_housing.jpg',
    'fig_1_1_pillars.jpg',
    'fig_2_1_location.jpg',
    'fig_2_3_general.jpg',
    'fig_2_4_prewar.jpg',
    'fig_2_5_landuse_a.jpg',
    'fig_2_5_landuse_b.jpg',
    'fig_2_6_a.jpg',
    'fig_2_6_b.jpg',
    'fig_2_6_map.jpg',
    'fig_urban_a.jpg',
    'fig_urban_b.jpg',
    'fig_2_7_pre.jpg',
    'fig_2_7_post.jpg',
    'fig_2_8_zones.jpg',
    'fig_2_9_zone_a.jpg',
    'fig_2_10_zone_b.jpg',
    'fig_2_11_zone_c.jpg',
    'fig_2_12_longterm.jpg',
    'fig_zone_a_inset.jpg',
    'fig_zone_b_inset.jpg',
    'fig_zone_c_inset.jpg',
    'fig_lt_zone_a.jpg',
    'fig_lt_zone_b.jpg',
    'fig_lt_zone_c.jpg',
    'fig_zoning.jpg',
  ];

  static WmlDocument build(Map<String, Uint8List> images) =>
      _AlTahreerDoc(images).build();
}

class _AlTahreerDoc {
  _AlTahreerDoc(this.images);

  final Map<String, Uint8List> images;

  static const String _navy = '2B4E8C';
  static const String _sage = 'A8D69F';
  static const String _teal = '1A6B6B';
  static const String _ink = '222222';
  static const String _muted = '6B7280';
  static const String _headerFill = '2B4E8C';
  static const String _alt = 'E8F0F2';

  static const WmlPageSize _a4 = WmlPageSize();
  static final WmlPageSize _a4Land = _a4.landscape;
  static const WmlPageMargins _inner = WmlPageMargins(
    top: 56,
    bottom: 48,
    left: 54,
    right: 54,
  );

  static const Map<String, (int, int)> _px = <String, (int, int)>{
    'cover_photo.jpg': (1600, 1066),
    'cover_map.jpg': (1200, 900),
    'logo_unhabitat.png': (407, 399),
    'logo_japan.png': (702, 639),
    'logo_credits.jpg': (316, 288),
    'logo_back.png': (407, 399),
    'photo_overview.jpg': (851, 1086),
    'photo_profile.jpg': (900, 1202),
    'photo_unrwa.jpg': (1400, 1061),
    'photo_housing.jpg': (1200, 707),
    'fig_1_1_pillars.jpg': (1020, 355),
    'fig_2_1_location.jpg': (1400, 1793),
    'fig_2_3_general.jpg': (1400, 939),
    'fig_2_4_prewar.jpg': (1400, 976),
    'fig_2_5_landuse_a.jpg': (1400, 793),
    'fig_2_5_landuse_b.jpg': (1400, 794),
    'fig_2_6_a.jpg': (953, 609),
    'fig_2_6_b.jpg': (953, 609),
    'fig_2_6_map.jpg': (1400, 579),
    'fig_urban_a.jpg': (1400, 759),
    'fig_urban_b.jpg': (1400, 761),
    'fig_2_7_pre.jpg': (1400, 649),
    'fig_2_7_post.jpg': (1400, 649),
    'fig_2_8_zones.jpg': (1400, 760),
    'fig_2_9_zone_a.jpg': (1400, 690),
    'fig_2_10_zone_b.jpg': (1400, 690),
    'fig_2_11_zone_c.jpg': (1400, 791),
    'fig_2_12_longterm.jpg': (1400, 760),
    'fig_zone_a_inset.jpg': (800, 507),
    'fig_zone_b_inset.jpg': (900, 447),
    'fig_zone_c_inset.jpg': (900, 540),
    'fig_lt_zone_a.jpg': (900, 441),
    'fig_lt_zone_b.jpg': (900, 450),
    'fig_lt_zone_c.jpg': (900, 540),
    'fig_zoning.jpg': (1020, 640),
  };

  WmlDocument build() {
    return WmlDocument(
      sections: <WmlSection>[
        _cover(),
        _section(blocks: _credits()),
        _section(blocks: _toc()),
        _section(blocks: _chapterOpener('1.', 'General', 'Overview', 'photo_overview.jpg', 'Photo © Anas Hilles')),
        ..._flow(_overview11()),
        ..._flow(_overview12()),
        _section(blocks: _chapterOpener('2.', 'Profile and', 'Functionality Assessment', 'photo_profile.jpg', 'Photo © Motaz-AlAqad')),
        ..._flow(_context()),
        _section(blocks: _prePostWar()),
        ..._flow(_conditions()),
        ..._flow(_functionality()),
        _section(blocks: _scoreResults()),
        ..._flow(
          _roadmap(),
          pageSize: _a4Land,
          breakKind: WmlSectionBreakKind.nextPage,
        ),
        _section(blocks: _zonesAndBudgets(), pageSize: _a4Land),
        ..._flow(_messages(), breakKind: WmlSectionBreakKind.nextPage),
        _section(blocks: _back()),
      ],
    );
  }

  WmlSection _cover() {
    const double topH = 546;
    const double photoH = 841.89 - topH;
    return WmlSection(
      pageSize: _a4,
      margins: const WmlPageMargins(top: 0, bottom: 0, left: 0, right: 0),
      blocks: <WmlBlock>[
        WmlFrame(
          x: 0,
          y: 0,
          width: _a4.width,
          height: topH,
          fillColor: _navy,
        ),
        _float('logo_unhabitat.png', x: 36, y: 28, width: 70),
        _float('logo_japan.png', x: 470, y: 22, width: 86),
        WmlFrame(
          x: 42,
          y: 268,
          width: 420,
          height: 150,
          blocks: <WmlBlock>[
            _line('AL TAHREER', size: 44, color: 'FFFFFF', bold: true, after: 0),
            _line('NEIGHBOURHOOD', size: 44, color: 'FFFFFF', bold: true, after: 0),
            _line('PROFILE', size: 44, color: 'FFFFFF', bold: true, after: 0),
          ],
        ),
        _float('cover_photo.jpg', x: 0, y: topH, width: _a4.width, height: photoH),
      ],
    );
  }

  List<WmlBlock> _credits() {
    return <WmlBlock>[
      _line(
        'Al Tahreer Neighbourhood Profile and Functionality Assessment · Khan Younis, Gaza',
        size: 18,
        color: _teal,
        italic: true,
        after: 22,
      ),
      _picture('logo_credits.jpg', width: 72, title: 'UN-Habitat'),
      _kv('Publication', 'Al Tahreer Neighbourhood Profile and Functionality Assessment | GAZA'),
      _kv('Copyright', '© United Nations Human Settlements Programme (UN–Habitat), 2026. All rights reserved.'),
      _kv('HS Number', 'HS/006/2026E'),
      _heading('Funded by', 2),
      _body('The Government of Japan'),
      _heading('Credits', 2),
      _body(
        'Write-up and coordination UN-Habitat Team: Lubna Shaheen, Laila Abu Baker, Wafa Butmeh.',
      ),
      _body(
        'Graphic Design and Layout: Barcelona Regional. Urban Development Agency. '
        'With the support of District 11, Barcelona City Council.',
      ),
      _body(
        'Excerpts from this publication may be produced without authorization on condition that the source is acknowledged. '
        'All photos used in this publication have been sourced from UN–Habitat, unless otherwise indicated.',
      ),
      _heading('Disclaimer', 2),
      _body(
        'The depiction and use of boundaries, geographic names and related data shown here are '
        'not warranted to be error-free nor do they imply official endorsement or acceptance by the United Nations. '
        'The designations employed and the presentation of material in this publication do not imply '
        'the expression of any opinion whatsoever on the part of the Secretariat of the United Nations '
        'concerning the delimitation of its frontiers or boundaries, or regarding its economic system '
        'or degree of development. The views expressed in this publication do not necessarily reflect '
        'the views of the United Nations Human Settlements Programme or its Executive Board.',
      ),
    ];
  }

  List<WmlBlock> _toc() {
    return <WmlBlock>[
      WmlToc(
        title: 'Table of Content',
        minLevel: 1,
        maxLevel: 3,
      ),
    ];
  }

  List<WmlBlock> _chapterOpener(
    String number,
    String lead,
    String trail,
    String photo,
    String credit,
  ) {
    return <WmlBlock>[
      _line('', after: 0, before: 0, pageBreak: true),
      WmlFrame(
        x: 54,
        y: 52,
        width: 28,
        height: 5,
        fillColor: '111111',
      ),
      WmlFrame(
        x: 54,
        y: 62,
        width: 56,
        height: 56,
        fillColor: _sage,
        blocks: <WmlBlock>[
          _line(number, size: 36, color: 'FFFFFF', bold: true, after: 0),
        ],
      ),
      WmlFrame(
        x: 122,
        y: 64,
        width: 280,
        height: 56,
        blocks: <WmlBlock>[
          _line(lead, size: 26, color: _sage, bold: true, after: 0),
          _line(trail, size: 26, color: _sage, after: 0),
        ],
      ),
      _line('', before: 90, after: 8),
      _picture(photo, width: 320, title: credit),
      _caption(credit),
    ];
  }

  List<WmlBlock> _overview11() {
    return <WmlBlock>[
      ..._sectionHead('1.1', 'Neighborhood Profiles: Translating Urban Evidence into Area-Based Recovery', pageBreak: true),
      _body(
        'Since October 2023, the Gaza Strip has experienced the most destructive war in its '
        'recent history, affecting civilians, residential areas, infrastructure, public buildings and '
        'essential public services. Against this backdrop of large-scale destruction, displacement, and '
        'systemic service collapse, Neighbourhood Profiles provide the localized analytical lens '
        'needed to understand how these impacts are experienced, distributed, and compounded at '
        'the neighbourhood scale. They respond to a post-conflict context where acute humanitarian '
        'needs intersect with long-standing urban vulnerabilities, and where spatially grounded '
        'and evidence-based urban analysis is essential to inform emergency response, guide recovery '
        'priorities, and support inclusive, resilient reconstruction.',
      ),
      _body(
        'The Neighbourhood Profiles are designed as practical decision-support tools that translate '
        'Gaza-wide urban analysis into neighbourhood-level evidence for action. Their added value lies '
        'in moving beyond damage-centric assessments to provide a multidimensional understanding of '
        'how neighborhoods function as integrated urban systems. Rather than treating neighbourhoods '
        'as isolated sites of destruction, the profiles examine them as interconnected spatial, social, '
        'and service systems, capturing how housing conditions, infrastructure networks, land '
        'and tenure arrangements, access to services, population dynamics, and local governance '
        'interact in a post-conflict environment.',
      ),
      _columnBreak(),
      _body(
        'By focusing on neighbourhood functionality and recovery potential, the profiles help '
        'advance area-based and phased recovery across the Gaza Strip. They allow decision-makers to '
        'prioritize interventions based on neighborhood functionality and recovery potential, rather than '
        'damage levels alone, identify spatial inequalities and compound vulnerabilities, and support '
        'coordinated, sequenced investments that reduce the risk of fragmented or maladaptive '
        'recovery. In this sense, the Neighbourhood Profiles provide an evidence base to inform '
        'humanitarian targeting, early recovery planning, and reconstruction sequencing, helping move '
        'from immediate stabilization to longer-term reconstruction through clearer priorities, '
        'locations, and timelines.',
      ),
      _body(
        'The Neighbourhood Profiles complement the Gaza Urban Profile by translating its '
        'common analytical reference for humanitarian, development, and planning actors working '
        'across the relief-to-recovery continuum into detailed, localized assessments that classify '
        'areas based on functionality, damage, access, and recovery potential. At the same time, the '
        'neighbourhood-level evidence generated through the profiles can be aggregated at '
        'the city scale, informing land use planning, infrastructure phasing, and service restoration in '
        'a coherent and integrated manner.',
      ),
    ];
  }

  List<WmlBlock> _overview12() {
    return <WmlBlock>[
      ..._sectionHead('1.2', 'Neighborhood Functionality Assessment Model', pageBreak: true),
      _body(
        'The methodology for developing the Neighbourhood Profiles is grounded in a '
        'comparative, area-based analysis that examines neighbourhood conditions before and after the '
        'war. It relies on the integration and triangulation of multiple data sources, including credible '
        'secondary data, high-resolution satellite imagery, and field verification and qualitative '
        'inputs where access permits. These data inputs are used to establish a spatially grounded '
        'understanding of the neighbourhood, identify changes in urban functionality, and verify how '
        'damage, service disruption, displacement, access constraints, and community coping '
        'mechanisms are reflected at the neighbourhood level. All indicators are reflected spatially at the '
        'neighbourhood level, allowing for localized analysis of urban functionality across key sectors.',
      ),
      _columnBreak(),
      _body(
        'The Neighborhood Functionality Assessment Model (NFAM) provides a structured, area-based '
        'framework for understanding how conflict has affected neighborhoods across six interrelated '
        'pillars: physical and spatial conditions, basic services and infrastructure, housing and '
        'tenure, economic livelihoods, social cohesion, and governance and planning. The model is '
        'grounded in a comparative analysis between the pre-war baseline and the post-war assessment, '
        'allowing the profile to measure the degree of functional loss and recovery potential, rather '
        'than documenting physical damage alone.',
      ),
      _body(
        'By assessing functionality pre and post war, the approach moves beyond damage mapping to '
        'capture how neighborhoods actually operate for residents, highlighting spatial disparities, '
        'sectoral interdependencies, and community coping mechanisms. The assessment process '
        'follows a clear sequence: first, data inputs are compiled and verified; second, the pre-war '
        'baseline is established; third, post-war conditions are assessed; fourth, the six functionality '
        'pillars are analyzed comparatively; and finally, the findings are translated into a neighbourhood '
        'profile and a phased recovery road map.',
      ),
      _picture('fig_1_1_pillars.jpg', width: 468, title: 'Figure 1.1'),
      _caption('Figure 1.1: Interdependent Pillars of Neighborhood Functionality Assessment'),
      _body(
        'The results directly inform programming at two levels. In the short term, they guide emergency '
        'response and early recovery by identifying priority areas for stabilization, such as restoring '
        'essential services, ensuring safe shelter use, protecting tenure through interim measures, '
        'supporting livelihoods, and strengthening community safety. This includes identifying '
        'immediate stabilization needs, access and debris clearance priorities, basic services restoration, '
        'shelter and housing support, protection and HLP support, livelihoods and community recovery, '
        'and conditions required for phased recovery and safe return.',
        pageBreak: true,
      ),
      _columnBreak(),
      _body(
        'In the long term, the findings shape recovery and sustainable development interventions '
        'by informing land use planning, infrastructure upgrading, tenure formalization, economic '
        'revitalization, and governance strengthening at the neighborhood scale. The methodology '
        'also supports the link between the Gaza-wide urban profile and localized neighbourhood '
        'profiles by translating citywide spatial patterns into neighbourhood-level insight, while '
        'allowing neighbourhood findings to feed back into broader planning, service restoration, '
        'and infrastructure phasing.',
      ),
      _body(
        'The neighborhood functionality assessment enables a smooth and strategic transition from '
        'emergency response to long-term recovery by ensuring that early interventions are scalable '
        'and aligned with long-term urban development objectives. By generating spatially grounded, '
        'neighborhood-level evidence that can be aggregated at the city scale, the assessment '
        'informs land use planning, infrastructure phasing, and service restoration in a coherent and '
        'integrated manner. At the same time, it provides a clear, sequenced recovery roadmap that '
        'clarifies priorities, locations, and timelines, helping to harmonize the efforts of implementing '
        'partners and donors, reduce fragmentation, and ensure that short-term stabilization actions '
        'contribute directly to resilient, inclusive, and sustainable urban recovery.',
      ),
      ..._figure12(),
    ];
  }

  List<WmlBlock> _context() {
    return <WmlBlock>[
      ..._sectionHead('2.1', 'Context Overview', pageBreak: true),
      _body(
        'Khan Younis, located in the southern part of the Gaza Strip, is one of the most significant '
        'urban centers in the area, characterized by a diverse urban fabric, ongoing expansion, '
        'and a dynamic socio-economic landscape. In recent years, and especially following '
        'the latest conflict, the city has experienced substantial demographic shifts, infrastructure '
        'damage, and increased pressure on housing, services, and public space. As a result, '
        'detailed neighborhood-level assessments are vital to inform early recovery actions and '
        'long-term urban planning.',
      ),
      _columnBreak(),
      _body(
        'Within this context, Al Tahreer neighborhood has emerged as a priority area for urban '
        'profiling. Al Tahreer neighborhood represents a transitioning semi-rural area where '
        'agricultural land coexists with emerging residential development. Gradual urbanization has '
        'been taking place, particularly in the northern and western parts of the neighborhood, where '
        'new housing plots have attracted returning residents and young families, reflecting its evolving '
        'role within the broader urban growth dynamics of Khan Younis.',
      ),
      _picture('fig_2_1_location.jpg', width: 220, title: 'Figure 2.1'),
      _caption('Figure 2.1: Al Tahreer neighborhood'),
      ..._sectionHead('2.1.1', 'Evolving Relationships with Khan Younis Refugee Camp', pageBreak: true),
      _body(
        'Al Tahreer has long been closely linked to Khan Younis Refugee Camp through shared '
        'infrastructure, services, livelihoods, and strong social and family ties. Al Tahreer is more '
        'peripheral and semi-rural in character, historically functioned as an expansion and buffer area, '
        'providing agricultural livelihoods, informal housing extensions, and institutional uses that '
        'complemented the overcrowded camp environment.',
      ),
      _columnBreak(),
      _body(
        'Following the war, these relationships intensified under conditions of widespread destruction and '
        'displacement. Extensive damage to Khan Younis Refugee Camp triggered large-scale population '
        'movements into surrounding neighborhoods. Al Tahreer underwent a more radical transformation '
        'after being designated as part of a humanitarian zone, with large areas converted into makeshift '
        'shelter sites hosting displaced populations from the camp and across Gaza.',
      ),
      _picture('photo_unrwa.jpg', width: 220, title: 'Figure 2.2'),
      _caption('Figure 2.2: Khan Younis Refugee Camp    Photo © UNRWA'),
    ];
  }

  List<WmlBlock> _prePostWar() {
    return <WmlBlock>[
      ..._sectionHead('2.2', 'Pre-War Assessment', pageBreak: true),
      _picture('fig_2_3_general.jpg', width: 468, title: 'Figure 2.3'),
      _caption('Figure 2.3: General Location of Al Tahreer Neighborhood'),
      _body(
        'Al Tahreer spans a large area and retains a semi-rural character, with land primarily allocated '
        'to agriculture, greenhouses, orchards, and nature reserves. While only a small portion is urbanized, '
        'early urban sprawl and low-income housing projects indicate gradual transformation, positioning '
        'Al Tahreer as a key spatial reserve for long-term growth. The neighborhood is characterized by '
        'dispersed low-rise housing, limited infrastructure networks, fragmented and largely unpaved roads, '
        'and extremely low population density. Land ownership is largely based on shared or government-allocated '
        'tenure, creating planning complexities, particularly as informal subdivision is emerging.',
      ),
      _picture('fig_2_4_prewar.jpg', width: 468, title: 'Figure 2.4'),
      _caption('Figure 2.4: Al Tahreer Neighborhood Pre-War Situation'),
      _legend(<String>[
        '1  Al-Aqsa University',
        '2  Polytechnic Institute',
        '3  Al-Kheir Hospital',
        '4  Administration buildings',
        '5  Albanian Mosque',
        '6  Sports fields',
        '7  Public park',
        '8  Khan Younis Cemetery',
        '9  Municipal Slaughterhouse',
        '10 Agricultural area',
        '11 Greenhouses',
        '12 Disperse low-rise housing',
      ]),
      ..._sectionHead('2.3', 'Post-War Assessment', pageBreak: true),
      _picture('fig_2_5_landuse_a.jpg', width: 230, title: 'Agriculture'),
      _picture('fig_2_5_landuse_b.jpg', width: 230, title: 'Greenhouses'),
      _caption('Figure 2.5: Post-war Landuse in Al Tahreer Neighbourhood'),
      _body(
        'The post-war assessment of Al Tahreer neighborhood reveals that the level and pattern '
        'of damage were shaped not only by the intensity and spatial concentration of conflict-related '
        'impacts, but also significantly by its pre-war urban conditions, infrastructure provision, '
        'and planning status. Pre-war Al Tahreer was characterized by a fragmented spatial structure, '
        'limited infrastructure coverage, mixed land uses, and unresolved planning and tenure '
        'conditions. These pre-existing vulnerabilities, combined with the neighborhood\'s designation '
        'as a humanitarian area and the subsequent large-scale influx of internally displaced persons, '
        'have resulted in extensive spatial disruption, the dominance of makeshift sites, and a '
        'near-complete erosion of neighborhood functionality.',
      ),
      _picture('fig_2_6_a.jpg', width: 230, title: 'Figure 2.6a'),
      _picture('fig_2_6_map.jpg', width: 468, title: 'Figure 2.6 map'),
      _picture('fig_2_6_b.jpg', width: 230, title: 'Figure 2.6b'),
      _caption('Figure 2.6: Al Tahreer Neighborhood Post-War Situation'),
    ];
  }

  List<WmlBlock> _conditions() {
    return <WmlBlock>[
      ..._sectionHead('2.3.1', 'Urban Fabric and Spatial Condition', pageBreak: true),
      _picture('fig_urban_a.jpg', width: 220, title: 'Urban fabric'),
      _body(
        'Post-war Al Tahreer Neighborhood is characterized by severe spatial disruption and '
        'loss of urban functionality. Approximately 85% of the neighborhood area is currently occupied '
        'by makeshift sites with IDPs from not only Khan Yunis governorate but from the rest of '
        'the Gaza Strip, due to the declaration of Al Tahreer neighborhood as a humanitarian area '
        'in October 2023.',
      ),
      _columnBreak(),
      _picture('fig_urban_b.jpg', width: 220, title: 'Damage status'),
      _body(
        'The emerging makeshift sites dominate the urban landscape and have replaced much of the '
        'pre-existing fabric. The north-western section, previously more structured, is partially damaged '
        'and retains limited rehabilitation potential. The overall urban layout remains highly unorganized, '
        'with irregular plot patterns and poor spatial definition, significantly constraining functionality, '
        'accessibility, and service delivery.',
      ),
      ..._sectionHead('2.3.2', 'Housing Conditions and Habitability', pageBreak: true),
      _picture('photo_housing.jpg', width: 220, title: 'Housing'),
      _body(
        'Housing conditions in Al Tahreer are critically strained. The average household size ranges '
        'between 6 and 10 people, indicating severe overcrowding, particularly within makeshift '
        'shelters and partially damaged structures. Overcrowding is compounded by the absence '
        'of adequate spatial standards and insufficient shelter materials. Safety levels, especially '
        'within housing units, are low, highlighting compromised housing protection, reduced privacy, '
        'and diminished habitability.',
      ),
      _columnBreak(),
      ..._sectionHead('2.3.3', 'Housing, Land, and Property (HLP) Context'),
      _body(
        'The pre-war HLP landscape continues to shape post-war recovery challenges. While beneficiaries '
        'of the planned housing project in the north-eastern area hold legal documentation, unresolved '
        'issues related to the original governmental land classification remain a potential source of dispute. '
        'Where informal development and makeshift occupation now dominate, tenure insecurity persists.',
      ),
      ..._sectionHead('2.3.4', 'Accessibility and Public Space Functionality'),
      _body(
        'Physical accessibility within Al Tahreer is severely constrained. In the north-western area, rubble '
        'and debris obstruct movement and isolate parts of the neighborhood. Narrow, sandy roads further '
        'limit accessibility for residents, emergency services, and humanitarian actors. The neighborhood '
        'lacks functional public spaces; safe and inclusive areas for social interaction remain absent.',
      ),
      ..._sectionHead('2.3.5', 'Basic Services and Infrastructure', pageBreak: true),
      _bullet('Water supply: domestic water from local wells; drinking water via trucks and small-scale desalination. Supply is fragile, costly, and vulnerable to disruption.'),
      _bullet('Sanitation: no formal sewerage network. All households depend on septic tanks, creating environmental contamination and public health risks.'),
      _bullet('Electricity: no public supply. Limited household solar panels restrict lighting, refrigeration, communication, and livelihoods.'),
      _columnBreak(),
      ..._sectionHead('2.3.6', 'Health and Education Services'),
      _body(
        'Health services are partially operational but face critical shortages of essential medicines and supplies. '
        'Educational services are also partially functioning, largely dependent on temporary or informal education '
        'initiatives rather than fully operational schools. Campuses of Al-Aqsa University and UCAS are largely '
        'occupied by makeshift shelters, making restoration of higher education very difficult.',
      ),
      ..._sectionHead('2.3.7', 'Livelihoods and Local Economy'),
      _body(
        'Local economic activity remains partially functional, with limited small-scale commercial activities. '
        'The majority of residents are highly dependent on external humanitarian assistance, reflecting '
        'widespread livelihood disruption, limited employment, and minimal income-generating capacity.',
      ),
      ..._sectionHead('2.3.8', 'Social Cohesion, Safety, and Local Governance'),
      _body(
        'Most residents of Al Tahreer are internally displaced, which has significantly weakened social cohesion '
        'and disrupted traditional community networks. The majority of respondents report feeling unsafe, '
        'especially at night, due to the absence of public lighting, damaged infrastructure, and stray dogs. '
        'Local governance and coordination mechanisms remain informal and limited.',
      ),
    ];
  }

  List<WmlBlock> _functionality() {
    return <WmlBlock>[
      ..._sectionHead('2.4', 'Functionality Assessment Results (Comparison: Pre- and Post-War)', pageBreak: true),
      _picture('fig_2_7_pre.jpg', width: 220, title: 'Pre-war 2023'),
      _picture('fig_2_7_post.jpg', width: 220, title: 'Post-war 2025'),
      _caption('Figure 2.7: Al Tahreer Neighbourhood Pre-War (2023) and Post-War (2025)'),
      _body(
        'This section presents the results of the neighborhood functionality assessment for Al '
        'Tahreer, comparing pre- and post-war conditions across six core pillars. The assessment provides a '
        'structured, area-based lens to understand how the war has altered urban functionality, service '
        'provision, housing conditions, livelihoods, social cohesion, and governance at the neighborhood level.',
      ),
      _columnBreak(),
      _body(
        'The functionality assessment of Al Tahreer neighborhood reflects a context of chronic '
        'vulnerability that has been further intensified by its designation as a humanitarian area and '
        'its role as a host for multiple makeshift sites. Unlike neighborhoods that experienced a sharp '
        'functional decline due to the war, Al Tahreer entered the conflict with already low baseline '
        'functionality across most pillars, and its post-war condition is strongly shaped by prolonged '
        'humanitarian use, large-scale displacement, and emergency-driven spatial arrangements.',
      ),
      _body(
        'Physical and spatial functionality remains critically constrained. Although the proportion of '
        'usable or partially usable buildings remained stable, the urban fabric continues to be highly '
        'fragmented due to makeshift shelters, informal extensions, and temporary structures. Public '
        'spaces remain non-functional, as many have been repurposed for emergency shelter.',
      ),
    ];
  }

  List<WmlBlock> _scoreResults() {
    return <WmlBlock>[
      _line('', pageBreak: true, after: 0),
      _body(
        'Basic services and infrastructure show persistently low functionality across all indicators. '
        'Water, sanitation, schools, and clinics remain severely disrupted, reflecting both conflict-related '
        'damage and prolonged overstretching of already weak service systems. Housing and tenure '
        'functionality remains relatively more resilient through informal repairs, while tenure security '
        'stays weak in makeshift areas.',
      ),
      _body(
        'Economic and livelihood functionality remains fragile and largely informal. A modest increase '
        'in functioning shops suggests survival-based activity, but formal economic activity, access to '
        'employment, and income sufficiency remain critically low. Social and community functionality '
        'is shaped by Al Tahreer’s role as a humanitarian host area: population continuity rose because '
        'of displaced residents, yet perceived safety and communal space use remain extremely low.',
      ),
      _caption('Table 1: Neighborhood Functionality Assessment for Al Tahreer Neighborhood'),
      _scoreTable(),
      _caption('جدول ٢: تقييم وظائف حي التحرير (اتجاه من اليمين إلى اليسار)'),
      _scoreTableRtl(),
      _body(
        'Overall, Al Tahreer’s functionality profile is shaped less by post-war damage alone and more '
        'by its prolonged transformation into a humanitarian landscape. These findings highlight the '
        'need for carefully sequenced, area-based interventions that stabilize humanitarian conditions '
        'in the short term while gradually transitioning Al Tahreer toward structured recovery.',
      ),
    ];
  }

  List<WmlBlock> _roadmap() {
    return <WmlBlock>[
      ..._sectionHead(
        '2.5',
        'Phased Recovery Roadmap and Spatial Prioritization',
        pageBreak: true,
        contentWidth: _a4Land.width - _inner.left - _inner.right,
      ),
      _body(
        'The post-war assessment of Al Tahreer reveals a distinct functionality profile that calls for tailored, '
        'area-based interventions. The neighborhood has been transformed into a humanitarian host '
        'area, with approximately 85 per cent of its land occupied by makeshift sites. Programming must '
        'prioritize humanitarian stabilization, protection, and critical service provision, while carefully '
        'sequencing steps toward structured recovery.',
      ),
      _columnBreak(),
      _body('Zones:'),
      _bullet('Zone A: Northwestern Al Tahreer – Partially Damaged'),
      _bullet('Zone B: Central & Northern Expanses – Dense Makeshift Camp'),
      _bullet('Zone C: Southeastern Periphery – Agricultural Open Land Reserve'),
      _picture('fig_2_8_zones.jpg', width: 340, title: 'Figure 2.8'),
      _caption('Figure 2.8: Spatial Projection of the Proposed Interventions'),
      ..._sectionHead(
        '2.5.1',
        'Short-Term Programmatic Interventions',
        pageBreak: true,
        contentWidth: _a4Land.width - _inner.left - _inner.right,
      ),
      _subhead('1. Physical & Spatial Stabilization'),
      _bullet('Temporary reinforcement of transitional shelters to support safe occupancy.'),
      _bullet('Debris clearance and informal road repair to ensure emergency access.'),
      _bullet('Temporary adaptation of public spaces for safe communal use.'),
      _subhead('2. Basic Services & Infrastructure'),
      _bullet('Emergency water supply through mobile tanks, desalination, and well rehabilitation.'),
      _bullet('Interim sanitation solutions in makeshift areas.'),
      _bullet('Temporary electricity solutions (solar kits, microgrids).'),
      _columnBreak(),
      _subhead('3. Housing & Tenure Security'),
      _bullet('Document makeshift site use and emerging HLP risks.'),
      _bullet('Identify informal occupation, disputed land, and secondary use.'),
      _bullet('Community-level dispute resolution and legal aid to prevent forced evictions.'),
    ];
  }

  List<WmlBlock> _zonesAndBudgets() {
    return <WmlBlock>[
      _heading('Short-Term Interventions: Zone A', 2, pageBreak: true),
      _picture('fig_2_9_zone_a.jpg', width: 680, title: 'Figure 2.9'),
      _picture('fig_zone_a_inset.jpg', width: 320, title: 'Zone A inset'),
      _caption('Figure 2.9: Zone A Interventions'),
      _body(
        'Prioritize rubble removal and road clearance along the main east-west artery; conduct rapid '
        'structural assessments of standing buildings; deploy STDM to document partially damaged '
        'properties; initiate spot repairs to water wells; and use cleared spaces for safe, lit community gathering points.',
      ),
      _heading('Short-Term Interventions: Zone B', 2, pageBreak: true),
      _picture('fig_2_10_zone_b.jpg', width: 680, title: 'Figure 2.10'),
      _picture('fig_zone_b_inset.jpg', width: 320, title: 'Zone B inset'),
      _caption('Figure 2.10: Zone B Interventions'),
      _heading('Short-Term Interventions: Zone C', 2, pageBreak: true),
      _picture('fig_2_11_zone_c.jpg', width: 680, title: 'Figure 2.11'),
      _picture('fig_zone_c_inset.jpg', width: 320, title: 'Zone C inset'),
      _caption('Figure 2.11: Zone C Interventions'),
      _heading('Short-Term Interventions: Phases', 2, pageBreak: true),
      _budget(
        'Table 5: Short Interventions Phase 1 Budget Breakdown',
        <(String, String, String)>[
          ('Emergency desludging of septic tanks and safe disposal of wastewater', '5,000 tanks', '750,000'),
          ('Construction of communal sanitation blocks', '25 blocks', '625,000'),
          ('Expansion and repair of small scale desalination plants', '3 plants', '450,000'),
          ('Rubble removal and clearance of the main east-west road', '2 km', '400,000'),
          ('Spot repairs and re-equipping of damaged domestic water wells', '3 wells', '90,000'),
          ('Cash-for-work program for solid waste collection, sorting, and disposal', '12 months (200 workers)', '600,000'),
          ('Deployment of two mobile health and nutrition clinics', '12 months (2 teams)', '480,000'),
          ('Total', '', '3,395,000'),
        ],
      ),
      _budget(
        'Table 6: Short Interventions Phase 2 Budget Breakdown',
        <(String, String, String)>[
          ('Installation of solar powered streetlights', '700', '1,050,000'),
          ('Establishment of temporary safe learning spaces for children', '10 structures', '100,000'),
          ('Distribution of agricultural input kits', '500 farms', '250,000'),
          ('Rehabilitation of agricultural access roads', '5 km', '75,000'),
          ('Household support package', '1,000 HHs', '1,555,000'),
        ],
      ),
      ..._sectionHead(
        '2.5.2',
        'Long-Term Programmatic Interventions',
        pageBreak: true,
        contentWidth: _a4Land.width - _inner.left - _inner.right,
      ),
      _body(
        'Plan a phased transition of the neighborhood from humanitarian to recovery-oriented functions; '
        'prepare incremental spatial upgrading including rehabilitation of damaged structures and '
        'reconstruction of key public spaces; introduce structured road networks, drainage, and basic '
        'infrastructure in priority zones; establish permanent water, sanitation, electricity, health, and '
        'education systems; regularize tenure; and restore the region\'s agricultural focus.',
      ),
      _picture('fig_2_12_longterm.jpg', width: 680, title: 'Figure 2.12'),
      _picture('fig_lt_zone_a.jpg', width: 220, title: 'LT A'),
      _picture('fig_lt_zone_b.jpg', width: 220, title: 'LT B'),
      _picture('fig_lt_zone_c.jpg', width: 220, title: 'LT C'),
      _caption('Figure 2.12: Long Term Spatial Interventions'),
      _budget(
        'Table 9: Long-Term Interventions Zone C Budget Breakdown',
        <(String, String, String)>[
          ('Installation of primary infrastructure networks (water, sewer, electricity)', '10 km', '3,000,000'),
          ('Construction of an internal road network', '8 km', '2,400,000'),
          ('Formal HLP adjudication and issuance of titles', '1,000 parcels', '300,000'),
          ('Construction of a local agricultural market', '1 market', '350,000'),
          ('Total', '', '6,050,000'),
        ],
      ),
    ];
  }

  List<WmlBlock> _messages() {
    return <WmlBlock>[
      ..._sectionHead('2.6', 'Key Strategic Messages', pageBreak: true),
      _subhead('Short-term stabilization must support long-term recovery'),
      _body(
        'Humanitarian and early recovery interventions in Al Tahreer should be deliberately designed '
        'to lay the foundation for long-term urban upgrading, avoiding parallel systems or temporary '
        'solutions that hinder future planning and neighborhood integration.',
      ),
      _subhead('Neighborhood-specific, sequenced recovery approaches are essential'),
      _body(
        'Short-term interventions must prioritize humanitarian stabilization, protection, and critical '
        'service provision, with medium- and long-term efforts carefully phased toward structured '
        'recovery and integration into broader city planning.',
      ),
      _columnBreak(),
      _subhead('STDM is central to inclusive and evidence-based recovery'),
      _body(
        'Deployment of STDM in Al Tahreer ensures that interventions address the actual conditions '
        'on the ground, mitigate tenure risks, and support conflict-sensitive, inclusive, and participatory '
        'recovery processes.',
      ),
      _subhead('Area-based sequencing prevents fragmented recovery'),
      _body(
        'Spatially phased interventions ensure that physical, social, economic, and governance measures '
        'reinforce one another, benefiting not only the neighborhood but also enhancing connectivity, '
        'service provision, and resilience across Khan Yunis and adjacent areas.',
      ),
      _subhead('Detailed, neighborhood-level planning is critical'),
      _body(
        'Operationalizing recovery requires granular, context-specific plans that account for functionality, '
        'spatial constraints, and the neighborhood\'s humanitarian-transformed landscape.',
      ),
      _subhead('Data-driven recovery ensures accountability and prioritization'),
      _body(
        'Combining satellite imagery, field verification, and structured functionality scoring provides a '
        'transparent and replicable basis for prioritizing interventions, mobilizing resources, and '
        'monitoring recovery over time.',
      ),
    ];
  }

  List<WmlBlock> _back() {
    return <WmlBlock>[
      _line('', pageBreak: true, after: 24),
      _picture('logo_back.png', width: 64, title: 'UN-Habitat'),
      _line('UN-Habitat', size: 22, color: _navy, bold: true, after: 6),
      _line(
        'Al Tahreer Neighbourhood Profile and Functionality Assessment | GAZA',
        size: 18,
        color: _teal,
        italic: true,
      ),
      _body('HS/006/2026E  ·  Funded by the Government of Japan'),
    ];
  }

  List<WmlSection> _flow(
    List<WmlBlock> blocks, {
    int columns = 2,
    WmlPageSize? pageSize,
    WmlSectionBreakKind breakKind = WmlSectionBreakKind.continuous,
  }) {
    final List<WmlSection> sections = <WmlSection>[];
    final List<WmlBlock> buf = <WmlBlock>[];
    var bufCols = 1;

    void flush() {
      if (buf.isEmpty) {
        return;
      }
      sections.add(
        _section(
          blocks: List<WmlBlock>.of(buf),
          pageSize: pageSize,
          columnCount: bufCols,
          columnSpace: bufCols > 1 ? 18 : 36,
          breakKind: sections.isEmpty
              ? breakKind
              : WmlSectionBreakKind.continuous,
        ),
      );
      buf.clear();
    }

    for (int i = 0; i < blocks.length; i++) {
      final WmlBlock block = blocks[i];
      final bool wideTable = block is WmlTable &&
          block.grid.fold<double>(0, (double a, double x) => a + x) > 280;
      final bool leadBreak = block is WmlParagraph &&
          block.properties.pageBreakBefore &&
          i + 1 < blocks.length &&
          blocks[i + 1] is WmlTable;
      final int want = (wideTable || leadBreak) ? 1 : columns;
      if (buf.isNotEmpty && want != bufCols) {
        flush();
      }
      bufCols = want;
      buf.add(block);
    }
    flush();
    return sections;
  }

  WmlSection _section({
    required List<WmlBlock> blocks,
    WmlPageSize? pageSize,
    int columnCount = 1,
    double columnSpace = 36,
    WmlSectionBreakKind breakKind = WmlSectionBreakKind.nextPage,
  }) {
    final WmlPageSize size = pageSize ?? _a4;
    return WmlSection(
      pageSize: size,
      margins: _inner,
      linkToPrevious: !size.isLandscape,
      columnCount: columnCount,
      columnSpace: columnSpace,
      breakKind: breakKind,
      header: const <WmlParagraph>[],
      footer: <WmlParagraph>[
        WmlParagraph(
          properties: WmlParagraphProps(
            justification: WmlJustification.left,
            spacingAfter: 0,
            pageNumberField: true,
          ),
          inlines: <WmlInline>[
            WmlRun(
              text: '1  |  Al Tahreer Neighborhood Profile',
              properties: WmlRunProps(
                bold: true,
                color: _ink,
                fontSizeHalfPoints: 18,
              ),
            ),
          ],
        ),
      ],
      blocks: blocks,
    );
  }

  List<WmlBlock> _sectionHead(
    String number,
    String title, {
    bool pageBreak = false,
    double? contentWidth,
  }) {
    final int level = number.split('.').length.clamp(1, 3);
    final int colon = title.indexOf(': ');
    final String lead = colon > 0 ? title.substring(0, colon + 1) : title;
    final String? trail = colon > 0 ? title.substring(colon + 2) : null;
    final WmlParagraph titlePara = WmlParagraph(
      properties: WmlParagraphProps(spacingBefore: 2, spacingAfter: 0),
      inlines: <WmlInline>[
        WmlRun(
          text: lead,
          properties: WmlRunProps(
            bold: true,
            color: _ink,
            fontSizeHalfPoints: 22,
          ),
        ),
        if (trail != null)
          WmlRun(
            text: ' $trail',
            properties: WmlRunProps(
              bold: true,
              color: _ink,
              fontSizeHalfPoints: 22,
            ),
          ),
      ],
    );
    WordToc.applyHeading(titlePara, level);
    titlePara.properties
      ..spacingBefore = 2
      ..spacingAfter = 0
      ..pageBreakBefore = false;
    return <WmlBlock>[
      if (pageBreak) _line('', pageBreak: true, after: 0, before: 0),
      WmlTable(
        grid: <double>[
          52,
          ((contentWidth ?? (_a4.width - _inner.left - _inner.right)) - 52)
              .clamp(200, 900),
        ],
        rows: <WmlTableRow>[
          WmlTableRow(
            cells: <WmlTableCell>[
              WmlTableCell(
                fillColor: _sage,
                blocks: <WmlBlock>[
                  WmlParagraph(
                    properties: WmlParagraphProps(
                      justification: WmlJustification.center,
                      spacingBefore: 8,
                      spacingAfter: 8,
                    ),
                    inlines: <WmlInline>[
                      WmlRun(
                        text: number,
                        properties: WmlRunProps(
                          bold: true,
                          color: 'FFFFFF',
                          fontSizeHalfPoints: 22,
                        ),
                      ),
                    ],
                  ),
                ],
              ),
              WmlTableCell(
                fillColor: 'F4FBF3',
                blocks: <WmlBlock>[titlePara],
              ),
            ],
          ),
        ],
      ),
    ];
  }

  List<WmlBlock> _figure12() {
    return <WmlBlock>[
      WmlTable(
        grid: <double>[156, 156, 156],
        rows: <WmlTableRow>[
          WmlTableRow(
            cells: <WmlTableCell>[
              _cell('Neighbourhood Profiles', header: true),
              _cell('Functionality pillars', header: true, fill: '3D7A4A'),
              _cell('Phased recovery', header: true, fill: _teal),
            ],
          ),
          WmlTableRow(
            cells: <WmlTableCell>[
              _cell(
                'Local urban evidence for area-based action: damage, access, services, and recovery potential.',
              ),
              _cell(
                'Six interdependent pillars: physical, services, housing, livelihoods, social, and governance.',
              ),
              _cell(
                'Short-term stabilization sequenced into long-term reconstruction, land use, and service restoration.',
              ),
            ],
          ),
        ],
      ),
      _caption('Figure 1.2: Neighborhood Profiles and Functionality Assessments'),
    ];
  }

  WmlParagraph _heading(String text, int level, {bool pageBreak = false}) {
    final WmlParagraph paragraph = WmlParagraph(
      properties: WmlParagraphProps(pageBreakBefore: pageBreak),
      inlines: <WmlInline>[
        WmlRun(
          text: text,
          properties: WmlRunProps(
            bold: true,
            color: level == 1 ? _navy : _teal,
            fontSizeHalfPoints: level == 1 ? 32 : 24,
          ),
        ),
      ],
    );
    WordToc.applyHeading(paragraph, level);
    paragraph.properties.pageBreakBefore = pageBreak;
    return paragraph;
  }

  WmlParagraph _line(
    String text, {
    int size = 20,
    String color = _ink,
    bool bold = false,
    bool italic = false,
    double after = 8,
    double before = 0,
    bool pageBreak = false,
  }) {
    return WmlParagraph(
      properties: WmlParagraphProps(
        spacingAfter: after,
        spacingBefore: before,
        pageBreakBefore: pageBreak,
      ),
      inlines: <WmlInline>[
        WmlRun(
          text: text,
          properties: WmlRunProps(
            bold: bold,
            italic: italic,
            color: color,
            fontSizeHalfPoints: size,
          ),
        ),
      ],
    );
  }

  WmlParagraph _body(String text, {bool pageBreak = false}) {
    return WmlParagraph(
      properties: WmlParagraphProps(
        justification: WmlJustification.justify,
        spacingAfter: 8,
        lineSpacing: 1.12,
        pageBreakBefore: pageBreak,
      ),
      inlines: <WmlInline>[
        WmlRun(
          text: text,
          properties: WmlRunProps(color: _ink, fontSizeHalfPoints: 20),
        ),
      ],
    );
  }

  WmlParagraph _bullet(String text) {
    return WmlParagraph(
      properties: WmlParagraphProps(
        spacingAfter: 4,
        indent: const WmlIndent(left: 16, hanging: 12),
        listLabel: '•',
      ),
      inlines: <WmlInline>[
        WmlRun(
          text: text,
          properties: WmlRunProps(color: _ink, fontSizeHalfPoints: 20),
        ),
      ],
    );
  }

  WmlParagraph _caption(String text) {
    return WmlParagraph(
      properties: WmlParagraphProps(spacingBefore: 2, spacingAfter: 10),
      inlines: <WmlInline>[
        WmlRun(
          text: text,
          properties: WmlRunProps(italic: true, color: _muted, fontSizeHalfPoints: 16),
        ),
      ],
    );
  }

  WmlParagraph _subhead(String text) {
    return WmlParagraph(
      properties: WmlParagraphProps(spacingBefore: 8, spacingAfter: 4),
      inlines: <WmlInline>[
        WmlRun(
          text: text,
          properties: WmlRunProps(bold: true, color: _teal, fontSizeHalfPoints: 21),
        ),
      ],
    );
  }

  WmlParagraph _kv(String key, String value) {
    return WmlParagraph(
      properties: WmlParagraphProps(spacingAfter: 6),
      inlines: <WmlInline>[
        WmlRun(
          text: '$key  ',
          properties: WmlRunProps(bold: true, color: _navy, fontSizeHalfPoints: 20),
        ),
        WmlRun(
          text: value,
          properties: WmlRunProps(color: _ink, fontSizeHalfPoints: 20),
        ),
      ],
    );
  }

  WmlParagraph _columnBreak() {
    return WmlParagraph(
      properties: WmlParagraphProps(columnBreakBefore: true, spacingAfter: 0),
      inlines: <WmlInline>[WmlRun(text: '')],
    );
  }

  WmlBlock _picture(
    String file, {
    required double width,
    required String title,
  }) {
    final Uint8List? bytes = images[file];
    if (bytes == null || bytes.isEmpty) {
      return _caption('[$title]');
    }
    final (int, int) px = _px[file] ?? (1400, 800);
    return WmlVisual(
      visual: OfficeVisual(
        kind: OfficeVisualKind.picture,
        title: title,
        imageBytes: bytes,
        width: width,
        height: width * px.$2 / px.$1,
      ),
    );
  }

  WmlBlock _float(
    String file, {
    required double x,
    required double y,
    required double width,
    double? height,
    PictureWrap wrap = PictureWrap.inFront,
  }) {
    final Uint8List? bytes = images[file];
    final (int, int) px = _px[file] ?? (1400, 800);
    final double h = height ?? width * px.$2 / px.$1;
    if (bytes == null || bytes.isEmpty) {
      return WmlFrame(x: x, y: y, width: width, height: h, fillColor: _navy);
    }
    return WmlVisual(
      visual: OfficeVisual(
        kind: OfficeVisualKind.picture,
        title: file,
        imageBytes: bytes,
        width: width,
        height: h,
        offsetX: x,
        offsetY: y,
        picture: PictureAdjust(wrap: wrap),
      ),
    );
  }

  WmlTable _legend(List<String> items) {
    final List<WmlTableRow> rows = <WmlTableRow>[];
    for (int i = 0; i < items.length; i += 2) {
      rows.add(
        WmlTableRow(
          cells: <WmlTableCell>[
            _cell(items[i]),
            _cell(i + 1 < items.length ? items[i + 1] : ''),
          ],
        ),
      );
    }
    return WmlTable(grid: <double>[230, 230], rows: rows);
  }

  WmlTable _budget(String caption, List<(String, String, String)> rows) {
    return WmlTable(
      grid: <double>[260, 110, 90],
      rows: <WmlTableRow>[
        WmlTableRow(
          cells: <WmlTableCell>[
            _cell(caption, header: true, span: 3),
          ],
        ),
        WmlTableRow(
          cells: <WmlTableCell>[
            _cell('Intervention', header: true),
            _cell('Quantity', header: true),
            _cell('USD', header: true),
          ],
        ),
        for (int i = 0; i < rows.length; i++)
          WmlTableRow(
            cells: <WmlTableCell>[
              _cell(
                rows[i].$1,
                bold: rows[i].$1 == 'Total',
                fill: rows[i].$1 == 'Total' ? 'D6E8EA' : (i.isEven ? _alt : 'FFFFFF'),
              ),
              _cell(
                rows[i].$2,
                bold: rows[i].$1 == 'Total',
                fill: rows[i].$1 == 'Total' ? 'D6E8EA' : (i.isEven ? _alt : 'FFFFFF'),
              ),
              _cell(
                rows[i].$3,
                bold: rows[i].$1 == 'Total',
                fill: rows[i].$1 == 'Total' ? 'D6E8EA' : (i.isEven ? _alt : 'FFFFFF'),
              ),
            ],
          ),
      ],
    );
  }

  WmlTable _scoreTableRtl() {
    const WmlJustification rtl = WmlJustification.right;
    return WmlTable(
      grid: <double>[260, 50, 50, 108],
      properties: WmlTableProps(
        rightToLeft: true,
        alignment: WmlJustification.right,
      ),
      rows: <WmlTableRow>[
        WmlTableRow(
          cells: <WmlTableCell>[
            _cell('المعيار', header: true, align: rtl),
            _cell('قبل', header: true, align: rtl),
            _cell('بعد', header: true, align: rtl),
            _cell('النتائج الرئيسية', header: true, align: rtl),
          ],
        ),
        _span('الركيزة ١  الوظائف المكانية والفيزيائية', 4, align: rtl),
        _data(
          <String>[
            'نسبة المباني الصالحة / الجزئية / المدمّرة',
            '٣',
            '١',
            'مقيّدة بشدة',
          ],
          align: rtl,
        ),
        _data(<String>['إمكانية الوصول للطرق', '٣', '٢', ''], align: rtl),
        _data(<String>['وظائف الفضاءات العامة الرئيسية', '١', '١', ''], align: rtl),
        _span('الركيزة ٢  الخدمات الأساسية والبنية التحتية', 4, align: rtl),
        _data(
          <String>['توفر المياه', '١', '١', 'متعطلة بشدة'],
          align: rtl,
        ),
        _data(<String>['وظائف الصرف الصحي', '١', '١', ''], align: rtl),
        _data(<String>['توفر الكهرباء', '٢', '١', ''], align: rtl),
        _data(<String>['حالة المدارس التشغيلية', '١', '١', ''], align: rtl),
        _data(<String>['حالة العيادات التشغيلية', '١', '٢', ''], align: rtl),
        _span('الركيزة ٣  السكن والحيازة', 4, align: rtl),
        _data(
          <String>['نسبة الوحدات السكنية الصالحة', '٣', '٣', 'تعافٍ سكني محدود'],
          align: rtl,
        ),
        _data(<String>['متوسط الطاقة الاستيعابية للوحدة', '٣', '١', ''], align: rtl),
        _data(<String>['أمن الحيازة', '٣', '٢', ''], align: rtl),
        _span('الركيزة ٤  الاقتصاد وسبل العيش', 4, align: rtl),
        _data(
          <String>['نسبة المحال العاملة', '٣', '٢', 'اقتصاد محلي ضعيف'],
          align: rtl,
        ),
        _data(<String>['وجود نشاط اقتصادي رسمي', '٣', '١', ''], align: rtl),
        _data(<String>['الوصول إلى مناطق العمل', '٣', '١', ''], align: rtl),
        _data(<String>['كفاية الدخل المحلي', '٣', '١', ''], align: rtl),
      ],
    );
  }

  WmlTable _scoreTable() {
    return WmlTable(
      grid: <double>[260, 50, 50, 108],
      rows: <WmlTableRow>[
        WmlTableRow(
          cells: <WmlTableCell>[
            _cell('Criteria', header: true),
            _cell('Pre', header: true),
            _cell('Post', header: true),
            _cell('Key results', header: true),
          ],
        ),
        _span('Pillar 1  Physical & Spatial Functionality', 4),
        _data(<String>['% of buildings usable / partially usable / destroyed', '3', '1', 'Critically constrained']),
        _data(<String>['Road accessibility', '3', '2', '']),
        _data(<String>['Functionality of key public spaces', '1', '1', '']),
        _span('Pillar 2  Basic Services & Infrastructure', 4),
        _data(<String>['Water availability', '1', '1', 'Severely disrupted']),
        _data(<String>['Sanitation functionality', '1', '1', '']),
        _data(<String>['Electricity availability', '2', '1', '']),
        _data(<String>['Operational status of schools', '1', '1', '']),
        _data(<String>['Operational status of clinics', '1', '2', '']),
        _span('Pillar 3  Housing & Tenure Functionality', 4),
        _data(<String>['% of habitable functional housing units', '3', '3', 'Limited housing recovery']),
        _data(<String>['Average bearing capacity per unit', '3', '1', '']),
        _data(<String>['Tenure security', '3', '2', '']),
        _span('Pillar 4  Economic & Livelihood Functionality', 4),
        _data(<String>['% of shops functioning', '3', '2', 'Weak local economy']),
        _data(<String>['Presence of formal economic activity', '3', '1', '']),
        _data(<String>['Distance/access to employment areas', '3', '1', '']),
        _data(<String>['Sufficient local income', '3', '1', '']),
        _span('Pillar 5  Social & Community Functionality', 4),
        _data(<String>['Population continuity (original vs IDPs)', '3', '1', 'Weak social functionality']),
        _data(<String>['Functionality of community-based structures', '1', '1', '']),
        _data(<String>['Perceived safety', '3', '1', '']),
        _data(<String>['Use of communal spaces', '3', '1', '']),
        _span('Pillar 6  Governance, Land Use & Planning', 4),
        _data(<String>['Land use changes (planned vs ad hoc)', '3', '2', 'Limited planning capacity']),
        _data(<String>['LGU access and presence', '2', '1', '']),
        _data(<String>['Availability of cadastral/planning data', '3', '1', '']),
      ],
    );
  }

  WmlTableRow _span(
    String text,
    int span, {
    WmlJustification align = WmlJustification.left,
  }) {
    return WmlTableRow(
      cells: <WmlTableCell>[
        WmlTableCell(
          gridSpan: span,
          fillColor: _teal,
          blocks: <WmlBlock>[
            WmlParagraph(
              properties: WmlParagraphProps(
                spacingAfter: 2,
                spacingBefore: 2,
                justification: align,
              ),
              inlines: <WmlInline>[
                WmlRun(
                  text: text,
                  properties: WmlRunProps(bold: true, color: 'FFFFFF', fontSizeHalfPoints: 18),
                ),
              ],
            ),
          ],
        ),
      ],
    );
  }

  WmlTableRow _data(
    List<String> texts, {
    WmlJustification align = WmlJustification.left,
  }) {
    return WmlTableRow(
      cells: <WmlTableCell>[
        for (final String text in texts) _cell(text, align: align),
      ],
    );
  }

  WmlTableCell _cell(
    String text, {
    bool header = false,
    bool bold = false,
    String? fill,
    int span = 1,
    WmlJustification align = WmlJustification.left,
  }) {
    return WmlTableCell(
      gridSpan: span,
      fillColor: fill ?? (header ? _headerFill : 'FFFFFF'),
      blocks: <WmlBlock>[
        WmlParagraph(
          properties: WmlParagraphProps(
            spacingAfter: 2,
            spacingBefore: 2,
            justification: align,
          ),
          inlines: <WmlInline>[
            WmlRun(
              text: text,
              properties: WmlRunProps(
                bold: header || bold,
                color: header ? 'FFFFFF' : _ink,
                fontSizeHalfPoints: 16,
              ),
            ),
          ],
        ),
      ],
    );
  }
}
