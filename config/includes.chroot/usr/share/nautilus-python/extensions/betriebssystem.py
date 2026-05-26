# BETRIEBSSYSTEM Nautilus right-click actions (python3-nautilus / Nautilus 4.0).
#
# Menu providers only -- they run on click, never per-file, so they can't slow
# down or hang the file manager. If anything here errors, Nautilus simply skips
# this extension (logged to the journal); the file manager keeps working.
#
#   * Open in VS Code        (any file/selection, and the folder background)
#   * Compress PDF           (Ghostscript /ebook)
#   * Merge PDFs             (pdfunite, 2+ selected)
import os
import shutil
import subprocess

import gi
gi.require_version("Nautilus", "4.0")
from gi.repository import Nautilus, GObject


def _paths(files):
    out = []
    for f in files:
        try:
            if f.get_uri_scheme() == "file":
                loc = f.get_location()
                p = loc.get_path() if loc else None
                if p:
                    out.append(p)
        except Exception:
            pass
    return out


class BetriebssystemMenus(GObject.GObject, Nautilus.MenuProvider):

    # --- selection menu ---
    def get_file_items(self, files):
        items = []
        paths = _paths(files)
        if not paths:
            return items

        if shutil.which("code"):
            mi = Nautilus.MenuItem(
                name="BS::OpenInCode", label="Open in VS Code",
                tip="Open the selection in Visual Studio Code")
            mi.connect("activate", self._open_in_code, paths)
            items.append(mi)

        pdfs = [p for p in paths if p.lower().endswith(".pdf")]
        if pdfs and shutil.which("gs"):
            mi = Nautilus.MenuItem(
                name="BS::CompressPDF", label="Compress PDF",
                tip="Shrink the PDF(s) with Ghostscript")
            mi.connect("activate", self._compress_pdf, pdfs)
            items.append(mi)
        if len(pdfs) >= 2 and shutil.which("pdfunite"):
            mi = Nautilus.MenuItem(
                name="BS::MergePDF", label="Merge PDFs",
                tip="Merge the selected PDFs into one")
            mi.connect("activate", self._merge_pdf, pdfs)
            items.append(mi)
        return items

    # --- folder background menu ("Open Folder in VS Code") ---
    def get_background_items(self, folder):
        paths = _paths([folder])
        if paths and shutil.which("code"):
            mi = Nautilus.MenuItem(
                name="BS::OpenFolderInCode", label="Open Folder in VS Code",
                tip="Open this folder in Visual Studio Code")
            mi.connect("activate", self._open_in_code, paths)
            return [mi]
        return []

    # --- handlers (each guarded; failures are silent) ---
    def _open_in_code(self, _menu, paths):
        try:
            subprocess.Popen(["code"] + paths)
        except Exception:
            pass

    def _compress_pdf(self, _menu, pdfs):
        for src in pdfs:
            try:
                base, _ = os.path.splitext(src)
                dst = base + "-compressed.pdf"
                subprocess.Popen([
                    "gs", "-sDEVICE=pdfwrite", "-dCompatibilityLevel=1.4",
                    "-dPDFSETTINGS=/ebook", "-dNOPAUSE", "-dQUIET", "-dBATCH",
                    "-sOutputFile=" + dst, src,
                ])
            except Exception:
                pass

    def _merge_pdf(self, _menu, pdfs):
        try:
            out = os.path.join(os.path.dirname(pdfs[0]), "merged.pdf")
            subprocess.Popen(["pdfunite"] + pdfs + [out])
        except Exception:
            pass
