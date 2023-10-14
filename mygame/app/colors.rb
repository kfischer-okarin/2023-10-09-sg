module DawnBringer32
  BLACK = { r: 0x00, g: 0x00, b: 0x00 }.freeze
  ALMOST_BLACK = { r: 0x22, g: 0x20, b: 0x34 }.freeze
  DARK_BROWN = { r: 0x45, g: 0x28, b: 0x3c }.freeze
  BROWN = { r: 0x66, g: 0x39, b: 0x31 }.freeze
  LIGHT_BROWN = { r: 0x8f, g: 0x56, b: 0x3b }.freeze
  ORANGE = { r: 0xdf, g: 0x71, b: 0x26 }.freeze
  TAN = { r: 0xd9, g: 0xa0, b: 0x66 }.freeze
  SKIN = { r: 0xee, g: 0xc3, b: 0x9a }.freeze
  YELLOW = { r: 0xfb, g: 0xf2, b: 0x36 }.freeze
  KIWI = { r: 0x99, g: 0xe5, b: 0x50 }.freeze
  GREEN = { r: 0x6a, g: 0xbe, b: 0x30 }.freeze
  CYAN = { r: 0x37, g: 0x94, b: 0x6e }.freeze
  DARK_OLIVE_GREEN = { r: 0x4b, g: 0x69, b: 0x2f }.freeze
  ARMY_GREEN = { r: 0x52, g: 0x4b, b: 0x24 }.freeze
  ONYX = { r: 0x32, g: 0x3c, b: 0x39 }.freeze
  AMERICAN_BLUE = { r: 0x3f, g: 0x3f, b: 0x74 }.freeze
  METALLIC_BLUE = { r: 0x30, g: 0x60, b: 0x82 }.freeze
  ROYAL_BLUE = { r: 0x5b, g: 0x6e, b: 0xe1 }.freeze
  CORNFLOWER_BLUE = { r: 0x63, g: 0x9b, b: 0xff }.freeze
  SKY_BLUE = { r: 0x5f, g: 0xcd, b: 0xe4 }.freeze
  LAVENDER_BLUE = { r: 0xcb, g: 0xdb, b: 0xfc }.freeze
  WHITE = { r: 0xff, g: 0xff, b: 0xff }.freeze
  CADET_GREY = { r: 0x9b, g: 0xad, b: 0xb7 }.freeze
  OLD_SILVER = { r: 0x84, g: 0x7e, b: 0x87 }.freeze
  DIM_GRAY = { r: 0x69, g: 0x6a, b: 0x6a }.freeze
  GRAY = { r: 0x52, g: 0x55, b: 0x59 }.freeze
  VIOLET = { r: 0x76, g: 0x42, b: 0x8a }.freeze
  RED = { r: 0xac, g: 0x32, b: 0x32 }.freeze
  LIGHT_RED = { r: 0xd9, g: 0x57, b: 0x63 }.freeze
  PINK = { r: 0xd7, g: 0x7b, b: 0xba }.freeze
  MOSS_GREEN = { r: 0x8f, g: 0x97, b: 0x41 }.freeze
  ANOTHER_BROWN = { r: 0x8a, g: 0x6f, b: 0x30 }.freeze
end

module Colors
  BACKGROUND = DawnBringer32::GRAY
  TEXT = DawnBringer32::WHITE
  DIRECTION_TRIANGLE = DawnBringer32::WHITE
  PLAYER = DawnBringer32::LAVENDER_BLUE
  CRESCENT_MOON = DawnBringer32::ALMOST_BLACK
  CRESCENT_MOON_SHURIKEN = DawnBringer32::WHITE
  BLOOD = DawnBringer32::RED
  FLASH = DawnBringer32::WHITE
  HP_BAR_BACKGROUND = DawnBringer32::OLD_SILVER
  HP_BAR = DawnBringer32::RED
end
