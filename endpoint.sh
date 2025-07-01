#!/bin/bash

# === BẮT ĐẦU: GHI LOG THỜI GIAN CẤU HÌNH AWS ===
dt=$(date '+%d/%m/%Y %H:%M:%S');
echo "$dt: START CONFIG AWS:"

# === CẤU HÌNH AWS PROFILE MẶC ĐỊNH ===
aws configure set aws_access_key_id "$AWS_ACCESS_KEY_ID" --profile default
aws configure set aws_secret_access_key "$AWS_SECRET_ACCESS_KEY" --profile default
aws configure set region "$AWS_REGION" --profile default
aws configure set output "text" --profile default

# === HIỂN THỊ THÔNG TIN DATABASE ===
echo "HOST: $DB_SERVER"
echo "USER: $DB_USER"
echo "PORT: $DB_PORT"
echo "TABLES: $TABLES"

# === CHẾ ĐỘ DUMP: ALL HOẶC CUSTOM ===
DB_MODE=${DB_MODE:-"CUSTOM"}     # Mặc định là CUSTOM nếu không truyền vào
DB_LIST=${DB_LIST:-"$DB_NAME"}   # Dùng biến cũ DB_NAME nếu không truyền DB_LIST

if [ "$DB_MODE" = "ALL" ]; then
    echo "MODE: DUMP ALL DATABASES"
    BACKUP_FILE="all_databases_$( date '+%F_%H-%M-%S' ).sql.gz"
else
    echo "MODE: DUMP CUSTOM DATABASES: $DB_LIST"
    BACKUP_FILE="multi_db_$( date '+%F_%H-%M-%S' ).sql.gz"
fi

echo "BACKUP FILE: $BACKUP_FILE"

# === BẮT ĐẦU DUMP ===
dt=$(date '+%d/%m/%Y %H:%M:%S');
echo "$dt: START DUMP DB"

if [ "$DB_MODE" = "ALL" ]; then
    mysqldump --single-transaction=TRUE \
        -h "$DB_SERVER" -P "$DB_PORT" -u "$DB_USER" -p"$DB_PASS" \
        --all-databases | gzip -9 > "$BACKUP_FILE"
else
    for DB in $DB_LIST; do
        echo ">> Dumping database: $DB"
        mysqldump --single-transaction=TRUE \
            -h "$DB_SERVER" -P "$DB_PORT" -u "$DB_USER" -p"$DB_PASS" \
            "$DB" $TABLES
    done | gzip -9 > "$BACKUP_FILE"
fi

# === KÍCH THƯỚC FILE ===
du -skh "$BACKUP_FILE"

# === BẮT ĐẦU UPLOAD LÊN S3 ===
dt=$(date '+%d/%m/%Y %H:%M:%S');
echo "$dt: END DUMP DB, START UPLOAD TO S3"

BACKUP_DIR=$( date '+%Y/%m/%d' )
echo "BACKUP DIR: $BACKUP_DIR"

aws --profile default \
    --region default \
    --endpoint-url "$AWS_ENDPOINT_URL" \
    s3 cp "$BACKUP_FILE" "$DB_DUMP_TARGET/$BACKUP_DIR/$BACKUP_FILE"

# === HOÀN TẤT ===
dt=$(date '+%d/%m/%Y %H:%M:%S');
echo "$dt: END UPLOAD TO S3"

# test build
