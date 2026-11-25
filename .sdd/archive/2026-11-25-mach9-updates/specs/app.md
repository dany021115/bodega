# Spec · app

## MA1 · Looking for a new Mach9 (D6)

- At start, the app asks for the latest release when the cache is missing or older than 24 h; then it looks every hour, asking the network only past 24 h.
- Offline it shows nothing new and no error.

Scenarios:
- **Given** a cache of 25 h, **then** one call. With a cache of 2 h, **then** none. (bloc test with a fake clock)
- **Given** a network failure, **then** no error state and no notice. (bloc test)

## MA2 · The notice and the card (D6)

- A newer release shows one notice per version ("Mach9 0.5.0 is out: update it in Engines").
- The engine card shows "Update to 0.5.0".
- The card says "Checked by Bodega" or "Not checked".

Scenarios:
- **Given** `updateAvailable` with 0.5.0, **then**:
  - the card has the button;
  - one notice shows, and not again for the same version. (widget and bloc tests)
- `pages_test` renders the card with the update at the window sizes, in English and Spanish.

## MA3 · The update (D4, D6)

- "Update" runs the install with its steps, the probe among them.
- A probe that fails shows its text, says that the previous version stays, and offers the log.

Scenarios:
- **Given** an install that ends with `Mach9CheckFailed`, **then** the card shows the failure text and a button for the log. (widget test)

## MA4 · Text

- Every new text is in both ARBs, with a description, and worded in `app/shared/text/`.
- `NoMach9Release` and `Mach9CheckFailed` get their `AppError` codes and their words.
