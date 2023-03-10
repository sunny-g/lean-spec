/-
# Message Fields

Building on the basic data definitions in [Core](Core.md), this module defines the message
fields that group together related information, and which in turn are combined to
define the messages.

For each field example text from an ATS message is provided, together with the corresponding
Lean value. Lean has a variety of ways to populate structure values, and all variants are
demonstrated.
-/

import LeanSpec.FPL.Core
import LeanSpec.lib.Temporal

open Core Temporal

namespace FPL.Field

/-
## Field 7: Aircraft identification and SSR mode and code

Field 7 is concerned with how a flight is identified for communication with air traffic control.
-/
structure Field7 where
  f7a  : AircraftIdentification
  f7bc : Option SsrCode

/-
### Field 7 Example

`-SAS912/A5100`
-/
example := Field7.mk ⟨"SAS912", by simp⟩ (some ⟨"5100", by simp⟩)

/-
## Field 8: Flight rules and type of flight

Field 8 provides information that determines how a flight is handled.
-/
structure Field8 where
  f8a : FlightRules
  f8b : Option TypeOfFlight

/-
### Field 8 Example

`-IS`
-/
example := Field8.mk .i (some .s)

/-
## Field 9: Number and type of aircraft and wake turbulence category

Field 9 provides information about the aircraft that will be used to conduct the flight.
-/
structure Field9 where
  f9a : Option NumberOfAircraft    -- only included for formation flights
  f9b : Option Doc8643.Designator  -- `none` indicates ZZZZ (refer field 18 TYP)
  f9c : WakeTurbulenceCategory

/-
`-2FK27/M`
-/
example := Field9.mk (some ⟨2, by simp⟩) (some ⟨"FK27", by simp⟩) .m

/-
### Field 9 Example

`-ZZZZ/L`
-/
example := Field9.mk none none .l

/-
## Field 10: Equipment and capabilities

Field 10 documents what equipment and capabilities the flight/aircraft has.
These items communicate what air traffic control can expect of the flight,
and limitations placed on the flight.
-/

structure Field10 where
  f10a : List CommNavAppCode    -- empty list indicates `N`
  f10b : List SurveillanceCode  -- empty list indicates `N`
  -- Exclude invalid combinations.
  inv  : ¬ (.b1 ∈ f10b ∧ .b2 ∈ f10b) ∧
         ¬ (.u1 ∈ f10b ∧ .u2 ∈ f10b) ∧
         ¬ (.v1 ∈ f10b ∧ .v2 ∈ f10b)

/-
### Field 10 Example

`-SAFR/SV1`
-/
example := (⟨[.s, .a, .f, .r], [.s, .v1], by simp⟩ : Field10)

/-
## Field 13: Departure aerodrome and time

Field 13 concerns the departure point and departure time of the flight.

A flight plan can be filed in the air, in which case AFIL is specified in the
departure point field.
-/
inductive ADep
  | adep (_ : Doc7910.Designator)
  | afil
deriving DecidableEq

def Field13a := Option ADep  -- `none` indicates ZZZZ (refer field 18 DEP)

structure Field13 where
  f13a : Field13a
  f13b : DTG

/-
### Field 13 Examples

`-EHAM0730`
-/
example := Field13.mk (some (.adep ⟨"EHAM", by simp⟩)) 63072027000

/-
`-AFIL1625`
-/
example : Field13 := ⟨some .afil, 63072059100⟩

/-
The designator in Field 13, if there is one.
-/
def Field13.desigOf : Field13 → Option Doc7910.Designator
  | ⟨some (.adep desig), _⟩ => desig
  | _                       => none

/-
## Field 15: Route

Field 15 describes the route the aircraft will follow to go from departure to destination.
This includes the level/altitude the flight operates at, and the speed of the aircraft.

Climbing between two levels, the upper limit can be specified, or _PLUS_ used to
indicate there is no nominated upper level.
-/
inductive UpperLevel
  | level (_ : VerticalPositionOfAircraft)
  | plus

/-
Indication of the change in speed and level.
-/
structure SpeedLevelChange where
  speed : TrueAirspeed
  level : VerticalPositionOfAircraft
  upper : Option UpperLevel

/-
### Speed/Level Change Example

`N0540A055PLUS`
-/
example : SpeedLevelChange where
  speed := ⟨⟨⟨540, sorry⟩, .kt, .ias, by simp⟩, sorry⟩
  level := ⟨5500, .feet, .altitude⟩
  upper := some .plus

/-
A specific point along the route, together with changes to speed, level and flight rules
planned to occur at the point.
-/
structure RoutePoint where
  pos  : Position
  chg  : Option SpeedLevelChange
  frul : Option FlightRule

/-
Between two points on a route, the aircraft can follow a documented ATS route, or
proceed directly.
-/
inductive Connector
  | rte (_ :RouteDesignator)
  | dct

/-
A route element is a point (and associated data) followed by the path to
the next element. Either, but not both, may be omitted.
-/
structure RouteElement where
  point : Option RoutePoint
  rte   : Option Connector
  -- At least one of point or connecting route must be populated.
  inv   : ¬ (point.isNone ∧ rte.isNone)

/-
The named waypoint in a route element, if there is one.
-/
def RouteElement.waypointOf : RouteElement → Option Waypoint
  | ⟨some rp, _, _⟩ => rp.pos.waypointOf
  | _               => none 

/-
The ATS route designator in a route element, if there is one.
-/
def RouteElement.atsRteOf : RouteElement → Option RouteDesignator
  | ⟨_, some (.rte rd), _⟩ => rd
  | _                      => none 

/-
Does the route element indicate _direct_ to the next point?
-/
def RouteElement.isDct : RouteElement → Bool
  | ⟨_, some .dct, _⟩ => true
  | _                 => false 

/-
The flight rules change in a route element, if there is one.
-/
def RouteElement.ruleOf : RouteElement → Option FlightRule
  | ⟨some rp, _, _⟩ => rp.frul
  | _               => none 

/-
Indicator the route description has been truncated.
-/
inductive Truncate | t

/-
The route consists of:
- optional standard instrument departure (SID);
- the non-empty list of elements;
- optional standard arrival route (STAR) or truncation indicator.
-/
structure Route where
  sid            : Option RouteDesignator
  elements       : List RouteElement
  starOrTruncate : Option (RouteDesignator ⊕ Truncate)
  -- Must be at least one route element.
  inv            : elements ≠ ∅ ∧
  -- Consecutive flight rules changes must be distinct.
                   let rules := (elements.map RouteElement.ruleOf).somes
                   rules.Pairwise' (· ≠ ·) ∧
  -- DCT must be followed by an explicit point.
                   elements.Pairwise' (·.isDct → ·.point.isSome) ∧
  -- An ATS route designator must connect to another designator or a named point.
                   elements.Pairwise'
                     (fun re₁ re₂ ↦ re₁.atsRteOf.isSome →
                        re₂.waypointOf.isSome ∨ (re₂.point.isNone ∧ re₂.atsRteOf.isSome))

/-
The list of named waypoints in a route.
-/
def Route.waypoints (rte : Route) : List Waypoint :=
  (rte.elements.map RouteElement.waypointOf).somes

/-
Field 15 consists of:
- the initial requested cruising speed;
- the initial requested cruising level;
- the route description.
-/
structure Field15 where
  f15a : TrueAirspeed
  f15b : Option VerticalPositionOfAircraft  -- `none` indicates VFR
  f15c : Route

/-
### Field 15 Example

`-M079F380 DCT WOL H65 RAZZI Q29 LIZZI DCT`
-/
def exElems := [
  RouteElement.mk none (some .dct) (by simp),
  RouteElement.mk (mkWpt ⟨"WOL", by simp⟩) (some (.rte ⟨"H65", by simp⟩)) (by simp),
  RouteElement.mk (mkWpt ⟨"RAZZI", by simp⟩) (some (.rte ⟨"Q29", by simp⟩)) (by simp),
  RouteElement.mk (mkWpt ⟨"LIZZI", by simp⟩) (some .dct) (by simp)
]
where mkWpt (wpt : Waypoint) : Option RoutePoint :=
  some ⟨.wpt wpt, none, none⟩

example := {
  f15a := ⟨⟨⟨0.79, sorry⟩, .mach, .tas, by simp⟩, by simp⟩,  -- M079
  f15b := some ⟨380, .feet, .flightLevel⟩,                   -- F380
  f15c := ⟨none, exElems, none, sorry⟩ : Field15             -- DCT WOL H65 RAZZI Q29 LIZZI DCT
}

/-
## Field 16: Destination aerodrome and total estimated elapsed time, destination alternate aerodrome(s)

Field 16 concerns the destination aerodrome, the flight time, and alternate destinations in the event
diversion is required.
-/
def Field16a := Option Doc7910.Designator  -- `none` indicates ZZZZ (refer field 18 DEST)

/-
Up to two alternates are allowed.
-/
def maxAlternateDestinations := 2

/-
Field 16 consists of:
- the planned destination aerodrome;
- the total estimated elapsed time (TEET) - i.e. the estimated flight duration;
- alternate destination aerodromes in case of a diversion.
-/
structure Field16 where
  f16a : Field16a
  f16b : Duration
  f16c : List Field16a
  -- TEET must be less than one day.
  inv  : f16b < Duration.oneDay ∧
  -- Upper limit on number of alternate aerodromes.
         f16c.length ≤ maxAlternateDestinations

/-
### Field 16 Example

`-EHAM0645 EBBR ZZZZ`
-/
example := Field16.mk (some ⟨"EHAM", by simp⟩) 24300 [some ⟨"EBBR", by simp⟩, none] (by simp)

/-
Are a departure and destination aerodrome the same?
-/
def adepIsAdes : Field13a → Field16a → Bool
  | none, none                       => True
  | some (.adep desig₁), some desig₂ => desig₁ = desig₂
  | _, _                             => False

/-
## Field 17: Arrival aerodrome and time

Field 17 concerns the actual arrival point and time, which will differ from the
planned destination in the event of a diversion.

Field 17 consists of:
- the actual arrival aerodrome designator;
- the actual arrival time;
- the name of the arrival aerodrome, if it has no designator.
-/

structure Field17 where
  f17a : Option Doc7910.Designator  -- `none` indicates ZZZZ
  f17b : DTG
  f17c : Option FreeText
  -- Exactly one of designator and aerodrome name must be populated.
  inv  : f17a.isNone ↔ f17c.isSome

/-
### Field 17 Example

`-ZZZZ1620 DEN HELDER`
-/
example := Field17.mk none 63072058800 (some ⟨"DEN HELDER", by simp⟩)

/-
## Field 18: Other information

Field 18 contains diverse other information about the flight.

The flight plan framework is presently undergoing major revision to benefit from the latest
information management best practices. The extant flight plan format has largely remained
unchanged for over 50 years. Allowed changes are limited by the the need for backwards
compatibility. As a result, additional information has typically been added as extra
data in field 18, with the result it is a rather disparate collection. It also means
that related information is recorded in separate parts of the message. For example, codes
that indicate navigation capability are presented in field 10a, but more recent Performance
Based Navigation (PBN) codes appears in item _PBN_ of field 18.

Up to 8 PBN codes may be specified.
-/
def maxPbnCodes := 8

/-
The elapsed time from departure to a point en-route. Usually a point where control is passed
between ATS providers.
-/
structure ElapsedTimePoint where
  point    : Doc7910.FIRDesignator ⊕ Position
  duration : Duration

/-
The `<` order relation on EET points. Ordered by the duration.
-/
instance : LT ElapsedTimePoint where
  lt := fun ⟨_,d₁⟩ ⟨_,d₂⟩ ↦ d₁ < d₂

/-
The `<` relation is decidable.
-/
instance (x y : ElapsedTimePoint) : Decidable (x < y) :=
  inferInstanceAs (Decidable (x.duration < y.duration))

/-
A point on the route where a delay occurs. The flight goes _off plan_ for
the duration. An example is a law enforcement flight that intends to conduct
covert operations and does not want to provide details of where it is flying.
-/
structure DelayPoint where
  point    : Waypoint
  duration : Duration

/-
The route to an alternate destination if the flight decides to divert en-route.
-/
structure RouteToRevisedDestination where
  destination : Doc7910.Designator
  route       : FreeText

/-
The various items that make up field 18.
-/
structure Field18 where
  sts  : List SpecialHandling
  pbn  : List PBNCode
  nav  : Option FreeText
  com  : Option FreeText
  dat  : Option FreeText
  sur  : Option FreeText
  dep  : Option (NameAndPosition ⊕ ATSUnit)
  dest : Option NameAndPosition
  reg  : List Registration
  eet  : List ElapsedTimePoint
  sel  : Option SelcalCode
  typ  : List (Option NumberOfAircraft × AircraftType)
  code : Option AircraftAddress
  dle  : List DelayPoint
  opr  : Option FreeText
  orgn : Option FreeText
  per  : Option AircraftPerformance
  altn : List NameAndPosition
  ralt : List LandingSite
  talt : List LandingSite
  rif  : Option RouteToRevisedDestination
  rmk  : Option FreeText
  -- Upper limit on number of PBN codes.
  inv  : pbn.length ≤ maxPbnCodes ∧
  -- Upper limit on number of alternate aerodromes.
         altn.length ≤ maxAlternateDestinations ∧
  -- EETs must be presented in ascending order.
         eet.ascendingStrict

/-
### Field 18 Example

`-PBN/A1B1C1D1O2S2T1 NAV/RNP2 REG/VHXYZ SEL/AFPQ CODE/7C6DDF OPR/FLYOU ORGN/YSSYABCO PER/C`
-/
example : Field18 := {
  sts := [],
  pbn := [.a1, .b1, .c1, .d1, .o2, .s2, .t1],
  nav := some ⟨"RNP2", by simp⟩,
  com := none,
  dat := none,
  sur := none,
  dep := none,
  dest := none,
  reg := [⟨"VHXYZ", by simp⟩]
  eet := [],
  sel := some ⟨"AFPQ", by simp⟩,
  typ := [],
  code := some ⟨"7C6DDF", by simp⟩,
  dle := [],
  opr := some ⟨"FLYOU", by simp⟩,
  orgn := some ⟨"YSSYABCO", by simp⟩,
  per := some .c,
  altn := [],
  ralt := [],
  talt := [],
  rif := none,
  rmk := none,
  inv := sorry
}


/-
## Field 22: Amendment

Field 22 specifies changes to an existing flight plan.
If any part of a field changes, the entire content of the new field
must be included in field 22, not just the sub-item that is changing.
-/
structure Field22 where
  f7  : Option Field7
  f8  : Option Field8
  f9  : Option Field9
  f10 : Option Field10
  f13 : Option Field13
  f15 : Option Field15
  f16 : Option Field16
  f18 : Option Field18
  -- At least one amendment must be specified.
  inv : ¬ (f7.isNone ∧f8.isNone ∧ f9.isNone ∧ f10.isNone ∧ f13.isNone ∧ f15.isNone ∧ f16.isNone ∧ f18.isNone)

/-
### Field 22 Example

`-8/IX-13/EDDN1230`
-/
example : Field22 where
  f7 := none
  f8 := some ⟨.i, some .x⟩
  f9 := none
  f10 := none
  f13 := some ⟨some (.adep ⟨"EDDN", by simp⟩), 63072027000⟩
  f15 := none
  f16 := none
  f18 := none
  inv := by simp


/-
## Consistency checks between fields

As noted earlier, the legacy nature of the flight planning messages means related information
is spread across disparate fields. As a result a number of constraints are required to ensure
consistency between fields. The majority of these relate to the relationship between field 18
other fields.

### Fields 8 and 15 (requested level)

 - If initial requested cruising level is VFR, initial flight rules must be V or Z.
-/
def F8F15Level : Field8 → Field15 → Prop
  | f8, ⟨_, none, _⟩ => f8.f8a ∈ [.v, .z]
  | _, _             => True

/-
### Fields 8 and 15 (flight rules)

- Rule changes only allowed if initial rules is Y or Z.
- If initial rules is Y (IFR first), first change must be to VFR.
- If initial rules is Z (VFR first), first change must be to IFR.
-/
def F8F15Rule (f8 : Field8) (f15 : Field15) : Prop :=
  match (f15.f15c.elements.map RouteElement.ruleOf).somes with
  | []        => f8.f8a ∈ [.i, .v]
  | .vfr :: _ => f8.f8a = .y
  | .ifr :: _ => f8.f8a = .z

/-
### Fields 9 and 18 (TYP)

- If designator in field 9b, field 18 TYP not populated.
- If ZZZZ in field 9b, aircraft type in field 18 TYP.
-/
def F9F18Typ : Field9 → Option Field18 → Prop
  | -- If designator in 9b, 18 TYP not populated.
    {f9b := some _, ..}, none
  | {f9b := some _, ..}, some {typ := [], ..}
  | -- If ZZZZ in 9b, must have aircraft type in 18 TYP.
    {f9b := none, ..}, some {typ := _::_, ..} => True
  | -- Any other combination is invalid.
    _, _                                      => False

/-
### Fields 10 and 18 (STS)

- Can't specify W (RVSM capable) in Field 10a and NONRVSM on Field 18 STS.
-/
def F10F18Sts : Field10 → Option Field18 → Prop
  | f10, some f18 => ¬ (.w ∈ f10.f10a ∧ .nonrvsm ∈ f18.sts)
  | _, _          => True

/-
### Fields 10 and 18 (PBN)

- If R specified in field 10a, PBN capability must be provided in Field 18 PBN.
-/
def F10F18Pbn : Field10 → Option Field18 → Prop
  | f10, none     => .r ∉ f10.f10a
  | f10, some f18 => .r ∈ f10.f10a ↔ f18.pbn ≠ ∅ 

/-
### Fields 10 and 18 (COM/NAV/DAT)

- If Z specified in field 10a, other information must be provided in at least one of COM,
NAV or DAT in Field 18.
-/
def F10F18Z : Field10 → Option Field18 → Prop
  | f10, none     => .z ∉ f10.f10a
  | f10, some f18 => .z ∈ f10.f10a ↔ f18.com.isSome ∨ f18.nav.isSome ∨ f18.dat.isSome

/-
### Fields 13 and 18 (DEP)

- If designator in field 13a, field 18 DEP not populated.
- If ZZZZ in field 13a, departure point in field 18 DEP.
- If AFIL in field 13a, ATS unit in field 18 DEP.
-/
def F13F18Dep : Field13 → Option Field18 → Prop
  | -- If designator in 13a, 18 DEP not populated.
    ⟨(some (.adep _)), _⟩, none
  | ⟨some (.adep _), _⟩, some {dep := none, ..}
  | -- If ZZZZ in 13a, must have departure point in 18 DEP.
    ⟨none, _⟩, some {dep := some (.inl _), ..}
  | -- If AFIL in 13a, must have ATS unit in 18 DEP.
    ⟨some .afil, _⟩, some {dep := some (.inr _), ..} => True
  | -- Any other combination is invalid.
    _, _                                             => False

/-
### Fields 15 and 18 (DLE)

- A delay point must be explicitly named in the route.
-/
def F15F18Dle : Field15 → Option Field18 → Prop
  | f15, some f18 => f18.dle.map (·.point) ⊆ f15.f15c.waypoints
  | _, _          => True

/-
### Fields 16 and 18 (DEST)

- If designator in field 16a, field 18 DEST not populated.
- If ZZZZ in field 16a, destination point in field 18 DEST.
-/
def F16F18Dest : Field16 → Option Field18 → Prop
  | -- If designator in 16a, 18 DEST not populated.
    {f16a := some _, ..}, none
  | {f16a := some _, ..}, some {dest := none, ..}
  | -- If ZZZZ in 16a, must have destination point in 18 DEST.
    {f16a := none, ..}, some {dest := some _, ..} => True
  | -- Any other combination is invalid.
    _, _                                          => False

/-
### Fields 16 and 18 (EET)

- All EETs must be less than the flight duration.
-/
def F16F18Eet : Field16 → Option Field18 → Prop
  | {f16b := teet, ..}, some f18 => f18.eet.all (·.duration < teet)
  | _, _                         => True

/-
### Fields 16 and 18 (DLE)

- The sum of the delays at the route points must be less than the flight duration.
-/
def F16F18Dle : Field16 → Option Field18 → Prop
  | {f16b := teet, ..}, some f18 => (f18.dle.map (·.duration)).add 0 < teet
  | _, _                         => True

/-
### Fields 16 and 18 (ALTN)

- For each ZZZZ entry in Field 16c, there must be a corresponding entry in Field 18 ALTN.
-/
def F16F18Altn : Field16 → Option Field18 → Prop
  | {f16c := [], ..}, none => True
  | {f16c := altn16, ..}, some {altn := altn18, ..}
                           => (altn16.filter (·.isNone)).length = altn18.length
  | _, _                   => False

/-
### Fields 16 and 17 (destination and arrival)

- Destination, if provided, must differ from actual arrival aerodrome.
-/
def F16F17Dest : Field16a → Option Field17 → Prop
  | some dest, some {f17a := some arr, ..} => dest ≠ arr
  | _, _                                   => True

end FPL.Field