#!/bin/bash

# === 1. LOG THỜI GIAN CẤU HÌNH AWS ===
dt=$(date '+%d/%m/%Y %H:%M:%S');
echo "$dt: START CONFIG AWS:"

# === 2. CẤU HÌNH AWS PROFILE MẶC ĐỊNH ===
aws configure set aws_access_key_id "$AWS_ACCESS_KEY_ID" --profile default
aws configure set aws_secret_access_key "$AWS_SECRET_ACCESS_KEY" --profile default
aws configure set region "$AWS_REGION" --profile default
aws configure set output "text" --profile default

# === 3. HIỂN THỊ THÔNG TIN DB ===
echo "HOST: $DB_SERVER"
echo "USER: $DB_USER"
echo "PORT: $DB_PORT"
echo "TABLES: $TABLES"

# === 4. CHẾ ĐỘ DUMP: ALL hoặc CUSTOM ===
DB_MODE=${DB_MODE:-"CUSTOM"}
DB_LIST=${DB_LIST:-"$DB_NAME"}

if [ "$DB_MODE" = "ALL" ]; then
    echo "MODE: DUMP ALL DATABASES"
    BACKUP_FILE="all_databases_$( date '+%F_%H-%M-%S' ).sql.gz"
else
    echo "MODE: DUMP CUSTOM DATABASES: $DB_LIST"
    BACKUP_FILE="multi_db_$( date '+%F_%H-%M-%S' ).sql.gz"
fi

echo "BACKUP FILE: $BACKUP_FILE"

# === 5. BẮT ĐẦU DUMP DB ===
dt=$(date '+%d/%m/%Y %H:%M:%S');
echo "$dt: START DUMP DB"

# Tìm command dump
DUMP_BIN=$(command -v mariadb-dump || command -v mysqldump)

if [ -z "$DUMP_BIN" ]; then
    echo "❌ Không tìm thấy mariadb-dump hoặc mysqldump!"
    exit 1
fi

# Tắt SSL từ phía client
export MYSQL_SSL_MODE=DISABLED

# Chuẩn bị args chung
COMMON_ARGS="--single-transaction=TRUE -h $DB_SERVER -P $DB_PORT -u $DB_USER -p$DB_PASS"

# Thêm ssl-mode=DISABLED nếu là mysqldump
if [[ "$DUMP_BIN" == *"mysqldump" ]]; then
    COMMON_ARGS="$COMMON_ARGS --ssl-mode=DISABLED"
fi

# Dump logic
if [ "$DB_MODE" = "ALL" ]; then
    $DUMP_BIN $COMMON_ARGS --all-databases | gzip -9 > "$BACKUP_FILE"
else
    for DB in $DB_LIST; do
        echo ">> Dumping database: $DB"
        $DUMP_BIN $COMMON_ARGS "$DB" $TABLES
    done | gzip -9 > "$BACKUP_FILE"
fi

# === 6. HIỂN THỊ DUNG LƯỢNG FILE ===
du -skh "$BACKUP_FILE"

# === 7. UPLOAD LÊN S3 ===
dt=$(date '+%d/%m/%Y %H:%M:%S');
echo "$dt: END DUMP DB, START UPLOAD TO S3"

BACKUP_DIR=$( date '+%Y/%m/%d' )
echo "BACKUP DIR: $BACKUP_DIR"

aws --profile default \
    --region default \
    --endpoint-url "$AWS_ENDPOINT_URL" \
    s3 cp "$BACKUP_FILE" "$DB_DUMP_TARGET/$BACKUP_DIR/$BACKUP_FILE"

# === 8. HOÀN TẤT ===
dt=$(date '+%d/%m/%Y %H:%M:%S');
echo "$dt: END UPLOAD TO S3"
