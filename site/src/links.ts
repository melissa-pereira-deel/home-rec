// Outbound links shared by the landing page and the standalone legal pages.
// Centralised so the download URL can never drift between the two — the GA4
// click tracking in Base.astro matches on the 'HomeRec.dmg' substring, so a
// divergent URL here would silently stop the download_click event firing.

export const DMG =
  'https://github.com/melissa-pereira-deel/home-rec/releases/latest/download/HomeRec.dmg';
export const REPO = 'https://github.com/melissa-pereira-deel/home-rec';
export const COFFEE = 'https://buymeacoffee.com/melissadebritto';
export const LICENSE = REPO + '/blob/main/LICENSE';
export const CONTACT = 'melissadebritto@gmail.com';

// Surfaced in the footer nav alongside Privacy/Terms/GitHub. Previously inline
// in Landing.astro; centralised here for the same reason as DMG.
export const RELEASE_NOTES = REPO + '/releases/latest';
export const SHA256 = REPO + '/releases/latest/download/HomeRec.dmg.sha256';
export const SUMSIGHT = 'https://www.sumsight.app';
