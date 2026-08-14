# linux-security-automation
def main():
    parser = argparse.ArgumentParser(
        description="YOLO resim ve etiketlerini kontrollu sekilde cogaltir."
    )
    parser.add_argument(
        "--operation",
        required=True,
        choices=["OP125", "OP350", "OP360"],
        help="Cogaltilacak operasyon",
    )
    parser.add_argument(
        "--apply",
        action="store_true",
        help="Bu secenek verilmeden dosya uretilmez.",
    )
    args = parser.parse_args()

    # Script: proje/scripts/augment_equal.py konumundaysa
    project_dir = Path(__file__).resolve().parents[1]

    sinif = input(
        "Cogaltilacak Sinif Adini Girin (Orn: T29): "
    ).strip().upper()

    img_dir = project_dir / "operations" / args.operation / sinif
    lbl_dir = project_dir / "operations" / args.operation / f"{sinif}L"

    print(f"\nOperasyon  : {args.operation}")
    print(f"Resim yolu: {img_dir}")
    print(f"Etiket yolu: {lbl_dir}")

    if not img_dir.is_dir() or not lbl_dir.is_dir():
        print("\nHATA: Gorsel veya etiket klasoru bulunamadi!")
        return

    image_extensions = {".jpg", ".jpeg", ".png"}

    images = sorted(
        path
        for path in img_dir.iterdir()
        if path.is_file()
        and path.suffix.lower() in image_extensions
        and "_aug_" not in path.stem.lower()
    )

    valid_pairs = []
    missing_labels = []

    for img_path in images:
        lbl_path = lbl_dir / f"{img_path.stem}.txt"

        if lbl_path.is_file():
            valid_pairs.append((img_path, lbl_path))
        else:
            missing_labels.append(img_path)

    print(f"\nBulunan orijinal resim : {len(images)}")
    print(f"Eslesen resim/etiket   : {len(valid_pairs)}")
    print(f"Etiketi olmayan resim  : {len(missing_labels)}")

    for img_path, lbl_path in valid_pairs[:10]:
        print(f"  OK: {img_path.name} <-> {lbl_path.name}")

    if len(valid_pairs) > 10:
        print(f"  ... ve {len(valid_pairs) - 10} cift daha")

    if not valid_pairs:
        print("\nHATA: Eslesen resim ve etiket cifti bulunamadi!")
        return

    # --apply verilmediyse sadece kontrol yapar.
    if not args.apply:
        print("\nDRY-RUN: Hicbir dosya uretilmedi.")
        print("Uretmek icin komuta --apply ekleyin.")
        return

    confirmation = input(
        "\nBulunan resim ve etiketler dogru mu? [e/H]: "
    ).strip().lower()

    if confirmation not in {"e", "evet", "y", "yes"}:
        print("Islem iptal edildi.")
        return

    try:
        multiplier = int(
            input("Her fotograftan KACAR TANE yeni turetsin?: ").strip()
        )
    except ValueError:
        print("HATA: Tam sayi girmelisiniz!")
        return

    if multiplier < 1:
        print("HATA: Cogaltma sayisi en az 1 olmalidir!")
        return

    planned_total = len(valid_pairs) * multiplier

    print(
        f"\nPlan: {len(valid_pairs)} fotograf x "
        f"{multiplier} = {planned_total} yeni veri"
    )

    confirmation = input("Uretim baslatilsin mi? [e/H]: ").strip().lower()

    if confirmation not in {"e", "evet", "y", "yes"}:
        print("Islem iptal edildi.")
        return

    generated = 0

    for src_img_path, src_lbl_path in valid_pairs:
        img = cv2.imread(str(src_img_path))

        if img is None:
            print(f"UYARI: Resim okunamadi: {src_img_path}")
            continue

        with open(src_lbl_path, "r", encoding="utf-8-sig") as file:
            lines = file.readlines()

        labels = []

        for line in lines:
            parts = line.strip().split()

            if len(parts) == 5:
                labels.append([float(value) for value in parts])

        if not labels:
            print(f"UYARI: Gecerli etiket yok: {src_lbl_path}")
            continue

        sequence = 1

        for _ in range(multiplier):
            # Var olan augmentation dosyalarinin ustune yazmaz.
            while True:
                new_base = f"{src_img_path.stem}_aug_{sequence:03d}"
                new_img_path = img_dir / f"{new_base}.jpg"
                new_lbl_path = lbl_dir / f"{new_base}.txt"

                if not new_img_path.exists() and not new_lbl_path.exists():
                    break

                sequence += 1

            aug_img, aug_labels = augment_data(img, labels)

            if not aug_labels:
                print(
                    f"UYARI: Donusumden sonra gecerli kutu kalmadi: "
                    f"{src_img_path.name}"
                )
                sequence += 1
                continue

            if not cv2.imwrite(str(new_img_path), aug_img):
                print(f"HATA: Resim yazilamadi: {new_img_path}")
                continue

            with open(new_lbl_path, "w", encoding="utf-8") as file:
                for label in aug_labels:
                    file.write(
                        f"{int(label[0])} "
                        f"{label[1]:.6f} "
                        f"{label[2]:.6f} "
                        f"{label[3]:.6f} "
                        f"{label[4]:.6f}\n"
                    )

            generated += 1
            sequence += 1

    print(f"\nISLEM TAMAM!")
    print(f"{generated} yeni resim/etiket cifti uretildi.")
