#!/bin/bash

# === 1. CẤU HÌNH AWS ===
dt=$(date '+%d/%m/%Y %H:%M:%S');
echo "$dt: START CONFIG AWS:"

aws configure set aws_access_key_id "$AWS_ACCESS_KEY_ID" --profile default
aws configure set aws_secret_access_key "$AWS_SECRET_ACCESS_KEY" --profile default
aws configure set region "$AWS_REGION" --profile default
aws configure set output "text" --profile default

# === 2. HIỂN THỊ THÔNG TIN DB ===
echo "HOST: $DB_SERVER"
echo "USER: $DB_USER"
echo "PORT: $DB_PORT"
echo "TABLES: $TABLES"

# === 3. CHỌN CHẾ ĐỘ DUMP ===
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

# === 4. DUMP DATABASE ===
dt=$(date '+%d/%m/%Y %H:%M:%S');
echo "$dt: START DUMP DB"

DUMP_BIN=$(command -v mariadb-dump || command -v mysqldump)
if [ -z "$DUMP_BIN" ]; then
    echo "❌ Không tìm thấy công cụ dump!"
    exit 1
fi

DUMP_ARGS="--single-transaction=TRUE -h $DB_SERVER -P $DB_PORT -u $DB_USER -p$DB_PASS"

if [[ "$DUMP_BIN" == *"mariadb-dump" ]]; then
    DUMP_ARGS="$DUMP_ARGS --ssl=0"
else
    DUMP_ARGS="$DUMP_ARGS --ssl-mode=DISABLED"
fi

if [ "$DB_MODE" = "ALL" ]; then
    $DUMP_BIN $DUMP_ARGS --all-databases | gzip -9 > "$BACKUP_FILE"
else
    for DB in $DB_LIST; do
        echo ">> Dumping database: $DB"
        $DUMP_BIN $DUMP_ARGS "$DB" $TABLES
    done | gzip -9 > "$BACKUP_FILE"
fi

# === 5. HIỂN THỊ DUNG LƯỢNG FILE ===
du -skh "$BACKUP_FILE"

# === 6. UPLOAD TO S3 (dùng s3api để tránh multipart) ===
dt=$(date '+%d/%m/%Y %H:%M:%S');
echo "$dt: END DUMP DB, START UPLOAD TO S3"

BACKUP_DIR=$(date '+%Y/%m/%d')
S3_KEY="${BACKUP_DIR}/${BACKUP_FILE}"
S3_BUCKET=$(echo "$DB_DUMP_TARGET" | sed 's|s3://||' | cut -d'/' -f1)

echo "BACKUP DIR: $BACKUP_DIR"
echo "Uploading to bucket: $S3_BUCKET, key: $S3_KEY"

aws s3api put-object \
    --bucket "$S3_BUCKET" \
    --key "$S3_KEY" \
    --body "$BACKUP_FILE" \
    --profile default \
    --region default \
    --endpoint-url "$AWS_ENDPOINT_URL"

# === 7. KẾT THÚC ===
dt=$(date '+%d/%m/%Y %H:%M:%S');
echo "$dt: END UPLOAD TO S3"
