import 'melody.dart';

// Traditional tunes, long in the public domain, written out note by note
// (C4 = 60).

/// "Twinkle, Twinkle, Little Star" ("Ah ! vous dirai-je, maman", 1761).
const twinkle = Melody(
  id: 'twinkle',
  bpm: 96,
  notes: [
    Note(60, 1), Note(60, 1), Note(67, 1), Note(67, 1), //
    Note(69, 1), Note(69, 1), Note(67, 2),
    Note(65, 1), Note(65, 1), Note(64, 1), Note(64, 1),
    Note(62, 1), Note(62, 1), Note(60, 2),
    Note(67, 1), Note(67, 1), Note(65, 1), Note(65, 1),
    Note(64, 1), Note(64, 1), Note(62, 2),
    Note(67, 1), Note(67, 1), Note(65, 1), Note(65, 1),
    Note(64, 1), Note(64, 1), Note(62, 2),
    Note(60, 1), Note(60, 1), Note(67, 1), Note(67, 1),
    Note(69, 1), Note(69, 1), Note(67, 2),
    Note(65, 1), Note(65, 1), Note(64, 1), Note(64, 1),
    Note(62, 1), Note(62, 1), Note(60, 2),
  ],
);

/// Brahms's Lullaby ("Wiegenlied", 1868).
const brahms = Melody(
  id: 'brahms',
  bpm: 88,
  notes: [
    Note(64, 0.75), Note(64, 0.25), Note(67, 2), //
    Note(64, 0.75), Note(64, 0.25), Note(67, 2),
    Note(64, 1), Note(67, 1), Note(72, 1.5), Note(71, 0.5),
    Note(69, 1), Note(69, 1), Note(67, 2),
    Note(62, 0.75), Note(64, 0.25), Note(65, 1), Note(62, 1),
    Note(62, 0.75), Note(64, 0.25), Note(65, 2),
    Note(62, 1), Note(65, 1), Note(71, 0.5), Note(69, 0.5),
    Note(67, 1), Note(71, 1), Note(72, 3),
    Note(60, 0.75), Note(60, 0.25), Note(72, 2), Note(69, 1),
    Note(65, 1), Note(67, 2), Note(64, 1),
    Note(60, 1), Note(65, 1), Note(67, 1), Note(69, 1), Note(67, 2),
    Note(60, 0.75), Note(60, 0.25), Note(72, 2), Note(69, 1),
    Note(65, 1), Note(67, 2), Note(64, 1),
    Note(60, 1), Note(65, 1), Note(64, 1), Note(62, 1), Note(60, 3),
  ],
);

/// "Frère Jacques" (French, 18th century).
const frereJacques = Melody(
  id: 'frere_jacques',
  bpm: 104,
  notes: [
    Note(60, 1), Note(62, 1), Note(64, 1), Note(60, 1), //
    Note(60, 1), Note(62, 1), Note(64, 1), Note(60, 1),
    Note(64, 1), Note(65, 1), Note(67, 2),
    Note(64, 1), Note(65, 1), Note(67, 2),
    Note(67, 0.5), Note(69, 0.5), Note(67, 0.5), Note(65, 0.5),
    Note(64, 1), Note(60, 1),
    Note(67, 0.5), Note(69, 0.5), Note(67, 0.5), Note(65, 0.5),
    Note(64, 1), Note(60, 1),
    Note(60, 1), Note(55, 1), Note(60, 2),
    Note(60, 1), Note(55, 1), Note(60, 2),
  ],
);

/// "Jingle Bells" (James Lord Pierpont, 1857), the chorus.
const jingleBells = Melody(
  id: 'jingle_bells',
  bpm: 138,
  instrument: Instrument.bells,
  notes: [
    Note(64, 1), Note(64, 1), Note(64, 2), //
    Note(64, 1), Note(64, 1), Note(64, 2),
    Note(64, 1), Note(67, 1), Note(60, 1.5), Note(62, 0.5), Note(64, 4),
    Note(65, 1), Note(65, 1), Note(65, 1.5), Note(65, 0.5),
    Note(65, 1), Note(64, 1), Note(64, 1), Note(64, 0.5), Note(64, 0.5),
    Note(64, 1), Note(62, 1), Note(62, 1), Note(64, 1),
    Note(62, 2), Note(67, 2),
    Note(64, 1), Note(64, 1), Note(64, 2),
    Note(64, 1), Note(64, 1), Note(64, 2),
    Note(64, 1), Note(67, 1), Note(60, 1.5), Note(62, 0.5), Note(64, 4),
    Note(65, 1), Note(65, 1), Note(65, 1.5), Note(65, 0.5),
    Note(65, 1), Note(64, 1), Note(64, 1), Note(64, 0.5), Note(64, 0.5),
    Note(67, 1), Note(67, 1), Note(65, 1), Note(62, 1), Note(60, 4),
  ],
);

/// "Silent Night" ("Stille Nacht", Franz Xaver Gruber, 1818), in eighths.
const silentNight = Melody(
  id: 'silent_night',
  bpm: 170,
  instrument: Instrument.bells,
  notes: [
    Note(67, 3), Note(69, 1), Note(67, 2), Note(64, 6), //
    Note(67, 3), Note(69, 1), Note(67, 2), Note(64, 6),
    Note(74, 4), Note(74, 2), Note(71, 6),
    Note(72, 4), Note(72, 2), Note(67, 6),
    Note(69, 4), Note(69, 2), Note(72, 3), Note(71, 1), Note(69, 2),
    Note(67, 3), Note(69, 1), Note(67, 2), Note(64, 6),
    Note(69, 4), Note(69, 2), Note(72, 3), Note(71, 1), Note(69, 2),
    Note(67, 3), Note(69, 1), Note(67, 2), Note(64, 6),
    Note(74, 4), Note(74, 2), Note(77, 3), Note(74, 1), Note(71, 2),
    Note(72, 6), Note(76, 6),
    Note(72, 2), Note(67, 2), Note(64, 2), Note(67, 3), Note(65, 1),
    Note(62, 2), Note(60, 12),
  ],
);

/// "We Wish You a Merry Christmas" (traditional English).
const merryChristmas = Melody(
  id: 'merry_christmas',
  bpm: 150,
  instrument: Instrument.bells,
  notes: [
    Note(62, 1), //
    Note(67, 1), Note(67, 0.5), Note(69, 0.5), Note(67, 0.5), Note(66, 0.5),
    Note(64, 1), Note(64, 1), Note(64, 1),
    Note(69, 1), Note(69, 0.5), Note(71, 0.5), Note(69, 0.5), Note(67, 0.5),
    Note(66, 1), Note(62, 1), Note(62, 1),
    Note(71, 1), Note(71, 0.5), Note(72, 0.5), Note(71, 0.5), Note(69, 0.5),
    Note(67, 1), Note(64, 1), Note(62, 0.5), Note(62, 0.5),
    Note(64, 1), Note(69, 1), Note(66, 1),
    Note(67, 3),
  ],
);

const lullabies = [brahms, twinkle, frereJacques];
const carols = [jingleBells, silentNight, merryChristmas];

Melody? melodyById(String id) =>
    [...lullabies, ...carols].where((m) => m.id == id).firstOrNull;
