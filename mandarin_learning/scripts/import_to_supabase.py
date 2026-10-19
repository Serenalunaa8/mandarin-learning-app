"""
Script Impor Kosakata Mandarin (HSK 1-6) ke Supabase.
Membaca file data/mandarin_id.json (5000 entri) dan melakukan batch upsert ke tabel vocabulary.

Cara menjalankan:
1. Pastikan python dan requests/supabase terinstal:
   pip install requests
2. Set environment variable atau isi SUPABASE_URL dan SUPABASE_SERVICE_ROLE_KEY di bawah:
   export SUPABASE_URL="https://your-project.supabase.co"
   export SUPABASE_SERVICE_KEY="your-service-role-key"
3. Jalankan:
   python scripts/import_to_supabase.py
"""

import os
import sys
import json
import time

try:
    import requests
except ImportError:
    print("[INFO] Modul 'requests' belum terinstal. Menggunakan urllib standar...")
    requests = None
    import urllib.request
    import urllib.error

BASE_DIR = os.path.dirname(os.path.dirname(os.path.abspath(__file__)))
JSON_FILE = os.path.join(BASE_DIR, "data", "mandarin_id.json")

SUPABASE_URL = os.environ.get("SUPABASE_URL", "").rstrip("/")
SUPABASE_KEY = os.environ.get("SUPABASE_SERVICE_KEY", "")

def batch_upsert(records, batch_size=100):
    if not SUPABASE_URL or not SUPABASE_KEY:
        print("[PERINGATAN] SUPABASE_URL atau SUPABASE_SERVICE_KEY belum diset di environment variable.")
        print("Silakan set environment variable terlebih dahulu:")
        print("  Windows CMD: set SUPABASE_URL=... && set SUPABASE_SERVICE_KEY=...")
        print("  PowerShell : $env:SUPABASE_URL='...'; $env:SUPABASE_SERVICE_KEY='...'")
        print("\nContoh URL: https://xyzcompany.supabase.co")
        return False

    url = f"{SUPABASE_URL}/rest/v1/vocabulary"
    headers = {
        "apikey": SUPABASE_KEY,
        "Authorization": f"Bearer {SUPABASE_KEY}",
        "Content-Type": "application/json",
        "Prefer": "resolution=merge-duplicates"
    }

    total = len(records)
    print(f"Memulai impor {total} kosakata ke Supabase (batch size = {batch_size})...")

    success_count = 0
    fail_count = 0

    for i in range(0, total, batch_size):
        chunk = records[i:i + batch_size]
        payload = []
        for r in chunk:
            payload.append({
                "id": r["id"],
                "hanzi": r["hanzi"],
                "pinyin": r["pinyin"],
                "arti_indonesia": r["arti_indonesia"],
                "translations": r.get("translations", []),
                "hsk_level": r["hsk_level"],
                "jenis_kata": r.get("jenis_kata"),
                "contoh_kalimat": r.get("contoh_kalimat", []),
                "sumber": r.get("sumber", "HSK 2.0 Official Vocabulary")
            })

        body = json.dumps(payload, ensure_ascii=False).encode("utf-8")

        try:
            if requests:
                res = requests.post(url, headers=headers, data=body, timeout=30)
                if res.status_code in (200, 201):
                    success_count += len(chunk)
                else:
                    fail_count += len(chunk)
                    print(f"[ERROR] Batch {i} - {i + len(chunk)} gagal: HTTP {res.status_code} - {res.text}")
            else:
                req = urllib.request.Request(url, data=body, headers=headers, method="POST")
                with urllib.request.urlopen(req, timeout=30) as resp:
                    if resp.status in (200, 201):
                        success_count += len(chunk)
                    else:
                        fail_count += len(chunk)
        except Exception as e:
            fail_count += len(chunk)
            print(f"[ERROR] Terjadi exception pada batch {i}: {e}")

        progress = min(100, int((i + len(chunk)) / total * 100))
        print(f"Progress: {progress}% ({success_count} berhasil, {fail_count} gagal)")
        time.sleep(0.1)

    print(f"\n[SELESAI] Total berhasil: {success_count}/{total}, Gagal: {fail_count}")
    return fail_count == 0

def main():
    if not os.path.exists(JSON_FILE):
        print(f"[ERROR] File tidak ditemukan: {JSON_FILE}")
        sys.exit(1)

    with open(JSON_FILE, "r", encoding="utf-8") as f:
        data = json.load(f)

    print(f"[OK] File {JSON_FILE} terbaca. Total entri: {len(data)}")
    batch_upsert(data)

if __name__ == "__main__":
    main()
