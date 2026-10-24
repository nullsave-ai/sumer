class_name Cfg
extends RefCounted
## ثوابت اللعبة المشتركة (أبعاد المسار، أنواع العوائق، إلخ).

const LANE_W := 2.4
const SEG_LEN := 36.0
const ROW_STEP := 9.0
const ROWS_PER_SEG := 4
const NUM_SEGS := 6
const ROAD_HALF := 4.8
const RECYCLE_Z := 14.0     # عندما تتجاوز حافة المقطع البعيدة هذا الخط خلف الكاميرا يُعاد تدويره

# أنواع العوائق
enum Kind { FREE, LOW, HIGH, FULL, WALL, MOVER }
# عوائق «العائلة»: الحجر دائم الصلابة، الشمس صلب في الواقع فقط، السراب صلب في السراب فقط
enum Family { STONE, SUN, MIR }

# أبعاد التصادم (نصف العمق، ارتفاع القمة، ارتفاع الفتحة السفلية للعوائق العلوية)
const HALF_DEPTH := {
	Kind.LOW: 0.6, Kind.HIGH: 0.5, Kind.FULL: 0.9, Kind.WALL: 0.8, Kind.MOVER: 0.7,
}
const LOW_TOP := 0.95
const HIGH_BOTTOM := 1.3
const HIGH_TOP := 2.4
const FULL_TOP := 2.7
const MOVER_TOP := 1.55

# حجم اللاعب
const PLAYER_HALF_W := 0.32
const PLAYER_HALF_D := 0.35
const PLAYER_H := 1.75
const SLIDE_H := 0.7

# أنواع التعزيزات
enum Power { MAGNET, SHIELD, BOOST, DOUBLE, ORB }
