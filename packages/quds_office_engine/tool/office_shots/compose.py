import sys
from PIL import Image, ImageDraw, ImageFont

FONTS = "/mnt/data/my_flutter_projects/dart packages/quds_office_suite/packages/quds_office_editor/fonts"
bold = ImageFont.truetype(f"{FONTS}/LiberationSans-Bold.ttf", 20)
small = ImageFont.truetype(f"{FONTS}/LiberationSans-Regular.ttf", 15)


def compose(left, right, out, crop_h, labels):
    a = Image.open(left).convert("RGB")
    b = Image.open(right).convert("RGB")
    a = a.crop((0, 0, a.width, crop_h))
    b = b.crop((0, 0, b.width, crop_h))
    pad, head = 24, 64
    w = a.width + b.width + pad * 3
    h = crop_h + head + pad
    img = Image.new("RGB", (w, h), (236, 240, 245))
    d = ImageDraw.Draw(img)
    for i, (im, (title, sub)) in enumerate(zip((a, b), labels)):
        x = pad + i * (a.width + pad)
        d.text((x, 12), title, font=bold, fill=(11, 31, 58))
        d.text((x, 38), sub, font=small, fill=(90, 100, 115))
        img.paste(im, (x, head))
        d.rectangle((x - 1, head - 1, x + im.width, head + im.height), outline=(190, 198, 210))
    img.save(out, optimize=True)


compose("/tmp/fid/out/review_office.png", "/tmp/fid/out/review_quds.png",
        sys.argv[1] + "/office_fidelity_word.png", 780,
        [("LibreOffice Writer", "Its own PDF export of review.docx"),
         ("quds_office_engine", "WordDeserializer + OfficePdfExport, pure Dart")])
compose("/tmp/fid/out/sales_office.png", "/tmp/fid/out/sales_quds.png",
        sys.argv[1] + "/office_fidelity_excel.png", 186,
        [("LibreOffice Calc", "Its own PDF export of sales.xlsx"),
         ("quds_office_engine", "SheetDeserializer + formula engine + OfficePdfExport")])
