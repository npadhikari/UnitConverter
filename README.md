# Converter NOW · Nepal Land Edition

A Flutter Android app for Nepali land measurement: a unit converter for
Ropani-Aana-Paisa-Daam and Bigha-Kattha-Dhur, a **naksa scanner** (OCR plus
plot-boundary detection), a **map plotter** and **area reports** you can
export as PDF.

> Rebuilt from [Converter NOW](https://github.com/ferraridamiano/ConverterNOW)
> by Damiano Ferrari (GPL-3.0). This version is a new codebase focused on land.

## Features

| Tab | What it does |
| --- | --- |
| **Convert** | Area (sq ft, m², Ropani, Aana, Paisa, Daam, Bigha, Kattha, Dhur, acre, hectare…), length (incl. haat), weight (tola, lal, pau, ser, dharni) and volume (mana, pathi, muri). Enter area as a single unit or directly as R-A-P-D / B-K-D. Accepts Devanagari digits. |
| **Scan** | Take or pick a photo of a cadastral map (naksa) or Lalpurja. **Google ML Kit OCR** (Latin + Devanagari) reads the scale (1:1250…), kitta, sheet, ward and printed area. Tap inside your plot and the **computer-vision pipeline** traces its boundary from the map lines. |
| **Plot** | Drag / add / delete corners on the photo or on a metric grid. Set the scale from one known side (real length, or mm on paper × map scale). Or enter **tape measurements** (4 sides + diagonal, or a triangle) and get the area with Heron's formula. |
| **Saved** | Plots stored on the phone, each with a report: area in every unit, side lengths (ft / m / haat), perimeter, Share and **Export PDF**. |

### Unit definitions

* Hill: 1 Ropani = 16 Aana = 64 Paisa = 256 Daam = 5,476 sq ft (508.74 m²)
* Terai: 1 Bigha = 20 Kattha = 400 Dhur = 72,900 sq ft (6,772.63 m²)

### Plot detection pipeline (`lib/core/plot_detector.dart`)

A pure-Dart version of the usual OpenCV steps, run in a background isolate
so the APK has no native OpenCV library:

1. Fix photo orientation, then resize (≤ 1000 px working copy)
2. Grayscale → blur → **adaptive mean threshold** (like `cv::adaptiveThreshold`)
3. **Dilate** to close gaps in the lines
4. **Flood fill** from the tapped point (like `cv::floodFill`), then a morphological close
5. **Border following** (like `cv::findContours`)
6. **Douglas–Peucker** simplification (like `cv::approxPolyDP`) and removal of collinear points

Area = shoelace formula over the corners × (metres per pixel)².

## Build

```bash
flutter pub get
flutter test
flutter build apk --release          # build/app/outputs/flutter-apk/app-release.apk
```

Requires Flutter 3.50+ (Dart 3.14) and the Android SDK (API 36). The release
build is signed with the debug key; add your own keystore in
`android/app/build.gradle.kts` before publishing to the Play Store.

## Disclaimer

Areas worked out from photos and hand measurements are estimates. Check them
with the Malpot / Napi (survey) office before buying or selling land.

## License

GPL-3.0, see [LICENSE](LICENSE).
