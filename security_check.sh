#!/bin/bash

# ==============================================================================
# yasin bez - siber guvenlik staj projesi
# linux uzerinde pratik log analizi ve bazi kritik hardening kontrolleri
# ==============================================================================

# Renk tanımlamaları (Çıktıların terminalde güzel görünmesi için)
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
NC='\033[0m' # No Color (Rengi sıfırla)

echo -e "${YELLOW}======================================================${NC}"
echo -e "🛡️  NetSec - Linux Guvenlik Scripti Calistirildi"
echo -e "Tarih: $(date)"
echo -e "${YELLOW}======================================================${NC}"
echo ""

# 1. BÖLÜM: SSH BAŞARISIZ GİRİŞ DENEMELERİ (Brute Force Tespiti)
echo -e "[*] Ssh loglari inceleniyor (/var/log/auth.log)..."

if [ -f /var/log/auth.log ]; then
    # Failed password satirlarini yakalayip, IP adreslerini filtreleyip sayiyoruz
    FAILED_IPS=$(grep "Failed password" /var/log/auth.log | awk '{print $(NF-3)}' | sort | uniq -c | sort -nr)
    
    if [ -z "$FAILED_IPS" ]; then
        echo -e "${GREEN}[+] Temiz: Supheli basarisiz SSH girisi bulunmadi.${NC}"
    else
        echo -e "${RED}[!] UYARI: Basarisiz giris denemesi yapan IP'ler ve adetleri:${NC}"
        echo "$FAILED_IPS"
    fi
else
    echo -e "${YELLOW}[!] Bilgi: /var/log/auth.log dosyasi bu sistemde bulunamadi.${NC}"
fi

echo ""
echo "------------------------------------------------------"
echo ""

# 2. BÖLÜM: PERMISSION (İZİN) KONTROLLERİ
echo -e "[*] Kritik sistem dosyalarinin izinleri kontrol ediliyor..."

# /etc/passwd kontrolü (Herkes okuyabilmeli ama yazamamalı - 644)
if [ -f /etc/passwd ]; then
    PASSWD_PERM=$(stat -c "%a" /etc/passwd)
    if [ "$PASSWD_PERM" -eq 644 ]; then
        echo -e "${GREEN}[+] /etc/passwd izinleri guvenli ($PASSWD_PERM).${NC}"
    else
        echo -e "${RED}[X] RISK: /etc/passwd izni hatali! Mevcut: $PASSWD_PERM, Olmasi gereken: 644${NC}"
    fi
fi

# /etc/shadow kontrolü (Sadece root okuyabilmeli - 600 veya 000)
if [ -f /etc/shadow ]; then
    SHADOW_PERM=$(stat -c "%a" /etc/shadow)
    if [ "$SHADOW_PERM" -eq 600 ] || [ "$SHADOW_PERM" -eq 000 ]; then
        echo -e "${GREEN}[+] /etc/shadow izinleri guvenli ($SHADOW_PERM).${NC}"
    else
        echo -e "${RED}[X] RISK: /etc/shadow gizliligi tehlikede! Mevcut: $SHADOW_PERM, Olmasi gereken: 600${NC}"
    fi
fi

echo ""
echo -e "${YELLOW}======================================================${NC}"
echo -e "${GREEN}[+] Tarama bitti.${NC}"
echo -e "${YELLOW}======================================================${NC}"
