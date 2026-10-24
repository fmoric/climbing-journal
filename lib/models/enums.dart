/// A gym is stored as a crag with [CragType.gym].
enum CragType { outdoor, gym }

/// Multi-pitch is a route with more than one pitch, not a discipline.
enum Discipline { sport, boulder, trad, gym }

/// Grades are stored exactly as entered, together with their system.
/// Conversion between systems is for display and stats only (M1-03).
enum GradeSystem { french, font, vScale, uiaa, yds }

enum AscentStyle { onsight, flash, redpoint, topRope, attempt, project }

/// Ascents are private unless the owner shares one with the circle.
enum AscentVisibility { private, circle }
