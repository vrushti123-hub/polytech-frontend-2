import '../models/models.dart';

class CatalogImageResolver {
  static String? forProduct(Product product) {
    return _byProductId[product.id] ??
        _imageFor(
          product.name,
          product.colors.isEmpty ? '' : product.colors.first,
        );
  }

  static String? forOrderItem(OrderItem item) {
    return _byProductId[item.productId] ??
        _imageFor(item.productName, item.color);
  }

  static String? forInventoryItem(InventoryItem item) {
    return _byProductId[item.productId] ??
        _imageFor(item.productName, item.color);
  }

  static String? _imageFor(String name, String color) {
    final normalizedName = _norm(_baseName(name));
    final normalizedColor = _norm(color);
    return _byNameColor['$normalizedName|$normalizedColor'] ??
        _byNameColor['${_norm(name)}|$normalizedColor'] ??
        _byName[_norm(name)] ??
        _byName[normalizedName];
  }

  static String _baseName(String value) {
    return value.replaceAll(RegExp(r'\s*\([^)]*\)\s*$'), '').trim();
  }

  static String _norm(String value) {
    return value.toLowerCase().replaceAll(RegExp(r'[^a-z0-9]+'), '');
  }

  static const Map<String, String> _byProductId = {
    'p001': 'assets/catalog/royal_black.png',
    'p002': 'assets/catalog/sentoza_beige.png',
    'p003': 'assets/catalog/executive_printed.png',
    'p004': 'assets/catalog/executive_cream.png',
    'p005': 'assets/catalog/deluxe_black.png',
    'p006': 'assets/catalog/sentoza_beige.png',
    'p007': 'assets/catalog/baby_101_gold_orange.png',
    'p008': 'assets/catalog/baby_wonder_red.png',
    'p009': 'assets/catalog/baby_101_pink.png',
    'p010': 'assets/catalog/tipoy_3007.png',
    'p011': 'assets/catalog/tipoy_3008.png',
    'p012': 'assets/catalog/dining_table_1.png',
    'p013': 'assets/catalog/cross_leg_dining_table.png',
    'p014': 'assets/catalog/round_stool.png',
    'p015': 'assets/catalog/fancy_stool.png',
  };

  static const Map<String, String> _byName = {
    '2071dc': 'assets/catalog/chair_2071_dc.png',
    '2062': 'assets/catalog/chair_2062_marble.png',
    '2061': 'assets/catalog/chair_2061_beige.png',
    '2060': 'assets/catalog/chair_2060_floral.png',
    'babywonder': 'assets/catalog/baby_wonder_red.png',
    'babystudiogold': 'assets/catalog/baby_studio_gold_red.png',
    'baby101gold': 'assets/catalog/baby_101_gold_orange.png',
    'babystudiosemi': 'assets/catalog/baby_studio_semi_pink.png',
    'babycomfort': 'assets/catalog/baby_comfort_orange.png',
    'babypogo': 'assets/catalog/baby_pogo_blue.png',
    'freezestand1': 'assets/catalog/freeze_stand_1.png',
    'freezestand2': 'assets/catalog/freeze_stand_2.png',
    'wegatable': 'assets/catalog/wega_table.png',
    'roundfixtable': 'assets/catalog/round_fix_table.png',
    'smallfixtable': 'assets/catalog/small_fix_table.png',
    'bigfixtable': 'assets/catalog/big_fix_table.png',
    'tipoy3008': 'assets/catalog/tipoy_3008.png',
    'tipoy3007': 'assets/catalog/tipoy_3007.png',
    'dome80ltr': 'assets/catalog/dome_80_ltr.png',
    'dome110ltr': 'assets/catalog/dome_110_ltr.png',
    'diningtable1': 'assets/catalog/dining_table_1.png',
    'crosslegdiningtable': 'assets/catalog/cross_leg_dining_table.png',
    'crosslegntv': 'assets/catalog/cross_leg_ntv.png',
    'patla104': 'assets/catalog/patla_104.png',
    'nanopatla': 'assets/catalog/nano_patla.png',
    'championpatla': 'assets/catalog/champion_patla.png',
    'patla103': 'assets/catalog/patla_103.png',
    'kitkatstool': 'assets/catalog/kitkat_stool.png',
    'sumo18': 'assets/catalog/sumo_18.png',
    'fancystool': 'assets/catalog/fancy_stool.png',
    'sumo21': 'assets/catalog/sumo_21.png',
    '22sumo': 'assets/catalog/sumo_22.png',
    'roundstool': 'assets/catalog/round_stool.png',
    'sumochair': 'assets/catalog/sumo_orange.png',
  };

  static const Map<String, String> _byNameColor = {
    'comfort|peach': 'assets/catalog/comfort_peach.png',
    'comfort|brown': 'assets/catalog/comfort_brown.png',
    'bellchair|orange': 'assets/catalog/bell_chair_orange.png',
    'bellchair|red': 'assets/catalog/bell_chair_red.png',
    'holiday|black': 'assets/catalog/holiday_black.png',
    'holiday|brown': 'assets/catalog/holiday1_brown.png',
    'sizzler|orange': 'assets/catalog/sizzler_orange.png',
    'flora|red': 'assets/catalog/flora_red.png',
    'steelleg1|blue': 'assets/catalog/steel_leg_1_blue.png',
    'steelleg2|green': 'assets/catalog/steel_leg_2_green.png',
    'fancychair|orange': 'assets/catalog/fancy_chair_orange.png',
    'webchair|green': 'assets/catalog/web_chair_green.png',
    'deluxe|brown': 'assets/catalog/deluxe_brown.png',
    'deluxe|black': 'assets/catalog/deluxe_black.png',
    '2021|brown': 'assets/catalog/chair_2021_brown.png',
    '2022|brown': 'assets/catalog/chair_2022_brown.png',
    'welcome|beige': 'assets/catalog/welcome_beige.png',
    'welcome|gold': 'assets/catalog/welcome_gold.png',
    'grand|black': 'assets/catalog/grand_black.png',
    'grand|gold': 'assets/catalog/grand_gold.png',
    'grand|maroon': 'assets/catalog/grand_maroon.png',
    'neo|maroon': 'assets/catalog/neo_maroon.png',
    'oppo|black': 'assets/catalog/oppo_black.png',
    'oppo|wood': 'assets/catalog/oppo_wood.png',
    'royaldc|cream': 'assets/catalog/royal_dc_cream.png',
    'duster|blackyellow': 'assets/catalog/duster_black_yellow.png',
    'royal|gold': 'assets/catalog/royal_gold.png',
    'royal|black': 'assets/catalog/royal_black.png',
    'sumo|orange': 'assets/catalog/sumo_orange.png',
    'sumo|wood': 'assets/catalog/sumo_wood.png',
    'mystique|blackmesh': 'assets/catalog/mystique_black_mesh.png',
    'mystique|blackpanel': 'assets/catalog/mystique_black_panel.png',
    'mystiq|wood': 'assets/catalog/mystiq_wood.png',
    'magic|maroon': 'assets/catalog/magic_maroon.png',
    'studio|gold': 'assets/catalog/studio_gold.png',
    'bond|black': 'assets/catalog/bond_black.png',
    'bond|gold': 'assets/catalog/bond_gold.png',
    'bond|peach': 'assets/catalog/bond_peach.png',
    'sentoza|blackdotted': 'assets/catalog/sentoza_black_dotted.png',
    'sentoza|glossyblack': 'assets/catalog/sentoza_glossy_black.png',
    'sentoza|beige': 'assets/catalog/sentoza_beige.png',
    'executive|maroon': 'assets/catalog/executive_maroon.png',
    'executive|cream': 'assets/catalog/executive_cream.png',
    'executive|printed': 'assets/catalog/executive_printed.png',
    'armlees|cream': 'assets/catalog/armlees_cream.png',
    'armlees|pink': 'assets/catalog/armlees_pink.png',
    'jupiter|red': 'assets/catalog/jupiter_red.png',
    'jupiter|green': 'assets/catalog/jupiter_green.png',
    'dignity1|blackred': 'assets/catalog/dignity_1_black_red.png',
    'dignity2|red': 'assets/catalog/dignity_2_red.png',
    'pearl|red': 'assets/catalog/pearl_red.png',
    'pearl|brown': 'assets/catalog/pearl_brown.png',
    'paragon1|red': 'assets/catalog/paragon_1_red.png',
    'paragon2|red': 'assets/catalog/paragon_2_red.png',
    'disneydc|redwhite': 'assets/catalog/disney_dc_red_white.png',
    'disney|red': 'assets/catalog/disney_red.png',
    'baby101|pink': 'assets/catalog/baby_101_pink.png',
    'baby101|orange': 'assets/catalog/baby_101_gold_orange.png',
    'baby101gold|orange': 'assets/catalog/baby_101_gold_orange.png',
    'babystudiosemi|pink': 'assets/catalog/baby_studio_semi_pink.png',
    'babycomfort|orange': 'assets/catalog/baby_comfort_orange.png',
    'babypogo|blue': 'assets/catalog/baby_pogo_blue.png',
  };
}
