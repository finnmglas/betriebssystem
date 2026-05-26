#!/usr/bin/env python3
"""Generate minimal, valid empty ODF documents for the GNOME Templates dir.

GNOME's "New Document" right-click menu lists files in ~/Templates. Office docs
must be real (zip-structured) ODF files to open cleanly, so we build minimal
valid .odt/.ods/.odp here and drop them into /etc/skel/Templates.

Run: python3 scripts/make-templates.py   (committed outputs, regenerate as needed)
"""
from pathlib import Path
import zipfile

REPO = Path(__file__).resolve().parent.parent
TPL = REPO / "config/includes.chroot/etc/skel/Templates"

MANIFEST = (
    '<?xml version="1.0" encoding="UTF-8"?>\n'
    '<manifest:manifest xmlns:manifest="urn:oasis:names:tc:opendocument:xmlns:manifest:1.0" manifest:version="1.3">\n'
    ' <manifest:file-entry manifest:full-path="/" manifest:media-type="{mime}"/>\n'
    ' <manifest:file-entry manifest:full-path="content.xml" manifest:media-type="text/xml"/>\n'
    '</manifest:manifest>\n'
)

DOCS = {
    "LibreOffice Writer Document.odt": (
        "application/vnd.oasis.opendocument.text",
        '<?xml version="1.0" encoding="UTF-8"?>\n'
        '<office:document-content '
        'xmlns:office="urn:oasis:names:tc:opendocument:xmlns:office:1.0" '
        'xmlns:text="urn:oasis:names:tc:opendocument:xmlns:text:1.0" '
        'office:version="1.3"><office:body><office:text><text:p/>'
        '</office:text></office:body></office:document-content>\n',
    ),
    "LibreOffice Calc Spreadsheet.ods": (
        "application/vnd.oasis.opendocument.spreadsheet",
        '<?xml version="1.0" encoding="UTF-8"?>\n'
        '<office:document-content '
        'xmlns:office="urn:oasis:names:tc:opendocument:xmlns:office:1.0" '
        'xmlns:table="urn:oasis:names:tc:opendocument:xmlns:table:1.0" '
        'office:version="1.3"><office:body><office:spreadsheet>'
        '<table:table table:name="Sheet1"><table:table-row>'
        '<table:table-cell/></table:table-row></table:table>'
        '</office:spreadsheet></office:body></office:document-content>\n',
    ),
    "LibreOffice Impress Presentation.odp": (
        "application/vnd.oasis.opendocument.presentation",
        '<?xml version="1.0" encoding="UTF-8"?>\n'
        '<office:document-content '
        'xmlns:office="urn:oasis:names:tc:opendocument:xmlns:office:1.0" '
        'xmlns:draw="urn:oasis:names:tc:opendocument:xmlns:drawing:1.0" '
        'office:version="1.3"><office:body><office:presentation>'
        '<draw:page draw:name="Slide 1"/></office:presentation>'
        '</office:body></office:document-content>\n',
    ),
}


def main() -> None:
    TPL.mkdir(parents=True, exist_ok=True)
    for name, (mime, content) in DOCS.items():
        path = TPL / name
        with zipfile.ZipFile(path, "w", zipfile.ZIP_DEFLATED) as z:
            # 'mimetype' MUST be the first entry and STORED (uncompressed).
            z.writestr(zipfile.ZipInfo("mimetype"), mime, compress_type=zipfile.ZIP_STORED)
            z.writestr("META-INF/manifest.xml", MANIFEST.format(mime=mime))
            z.writestr("content.xml", content)
        print(f"  wrote {path.relative_to(REPO)}")
    print("templates: done")


if __name__ == "__main__":
    main()
