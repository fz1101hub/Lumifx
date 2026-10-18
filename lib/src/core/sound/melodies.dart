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

/// "Au clair de la lune" (18th century).
const auClairDeLaLune = Melody(
  id: 'au_clair',
  bpm: 92,
  notes: [
    Note(60, 1), Note(60, 1), Note(60, 1), Note(62, 1), //
    Note(64, 2), Note(62, 2),
    Note(60, 1), Note(64, 1), Note(62, 1), Note(62, 1), Note(60, 4),
    Note(60, 1), Note(60, 1), Note(60, 1), Note(62, 1),
    Note(64, 2), Note(62, 2),
    Note(60, 1), Note(64, 1), Note(62, 1), Note(62, 1), Note(60, 4),
    Note(62, 1), Note(62, 1), Note(62, 1), Note(62, 1),
    Note(57, 2), Note(57, 2),
    Note(62, 1), Note(60, 1), Note(59, 1), Note(57, 1), Note(55, 4),
    Note(60, 1), Note(60, 1), Note(60, 1), Note(62, 1),
    Note(64, 2), Note(62, 2),
    Note(60, 1), Note(64, 1), Note(62, 1), Note(62, 1), Note(60, 4),
  ],
);

/// "Mary Had a Little Lamb" (Lowell Mason, 1830).
const maryLamb = Melody(
  id: 'mary_lamb',
  bpm: 112,
  notes: [
    Note(64, 1), Note(62, 1), Note(60, 1), Note(62, 1), //
    Note(64, 1), Note(64, 1), Note(64, 2),
    Note(62, 1), Note(62, 1), Note(62, 2),
    Note(64, 1), Note(67, 1), Note(67, 2),
    Note(64, 1), Note(62, 1), Note(60, 1), Note(62, 1),
    Note(64, 1), Note(64, 1), Note(64, 1), Note(64, 1),
    Note(62, 1), Note(62, 1), Note(64, 1), Note(62, 1),
    Note(60, 4),
  ],
);

/// "Hot Cross Buns" (an old street cry): three notes, the first tune to
/// play.
const hotCrossBuns = Melody(
  id: 'hot_cross_buns',
  bpm: 100,
  notes: [
    Note(64, 1), Note(62, 1), Note(60, 2), //
    Note(64, 1), Note(62, 1), Note(60, 2),
    Note(60, 0.5), Note(60, 0.5), Note(60, 0.5), Note(60, 0.5),
    Note(62, 0.5), Note(62, 0.5), Note(62, 0.5), Note(62, 0.5),
    Note(64, 1), Note(62, 1), Note(60, 2),
  ],
);

/// "Ode to Joy" (Beethoven, Ninth Symphony, 1824), its first lines.
const odeToJoy = Melody(
  id: 'ode_to_joy',
  bpm: 108,
  notes: [
    Note(64, 1), Note(64, 1), Note(65, 1), Note(67, 1), //
    Note(67, 1), Note(65, 1), Note(64, 1), Note(62, 1),
    Note(60, 1), Note(60, 1), Note(62, 1), Note(64, 1),
    Note(64, 1.5), Note(62, 0.5), Note(62, 2),
    Note(64, 1), Note(64, 1), Note(65, 1), Note(67, 1),
    Note(67, 1), Note(65, 1), Note(64, 1), Note(62, 1),
    Note(60, 1), Note(60, 1), Note(62, 1), Note(64, 1),
    Note(62, 1.5), Note(60, 0.5), Note(60, 2),
  ],
);

const lullabies = [brahms, twinkle, frereJacques, auClairDeLaLune];
const carols = [jingleBells, silentNight, merryChristmas];

/// Simple tunes to learn on the light piano, besides the lullabies.
const pianoTunes = [hotCrossBuns, maryLamb, odeToJoy];

Melody? melodyById(String id) => [...lullabies, ...carols, ...pianoTunes]
    .where((m) => m.id == id)
    .firstOrNull;
