#!/bin/bash

# Comet Cursor control script

case "$1" in
    start)
        echo "Запуск Comet Cursor..."
        # Проверяем, не запущено ли уже приложение
        if pgrep -f "comet-cursor" > /dev/null; then
            echo "Comet Cursor уже запущен!"
            exit 1
        fi
        
        # Компилируем последнюю версию
        go build -o comet-cursor main.go
        
        if [ $? -eq 0 ]; then
            # Запускаем в фоне
            ./comet-cursor &
            echo "Comet Cursor запущен в фоне (PID: $!)"
            echo $! > .comet-cursor.pid
        else
            echo "Ошибка компиляции!"
            exit 1
        fi
        ;;
    stop)
        echo "Остановка Comet Cursor..."
        if [ -f .comet-cursor.pid ]; then
            PID=$(cat .comet-cursor.pid)
            if kill $PID 2>/dev/null; then
                echo "Comet Cursor остановлен (PID: $PID)"
            else
                echo "Процесс не найден, возможно уже остановлен"
            fi
            rm -f .comet-cursor.pid
        else
            # Пытаемся найти и остановить процесс
            pkill -f "comet-cursor"
            if [ $? -eq 0 ]; then
                echo "Comet Cursor остановлен"
            else
                echo "Comet Cursor не найден"
            fi
        fi
        ;;
    restart)
        $0 stop
        sleep 1
        $0 start
        ;;
    status)
        if pgrep -f "comet-cursor" > /dev/null; then
            echo "Comet Cursor запущен"
            pgrep -f "comet-cursor"
        else
            echo "Comet Cursor не запущен"
        fi
        ;;
    *)
        echo "Использование: $0 {start|stop|restart|status}"
        echo ""
        echo "  start   - Запустить Comet Cursor"
        echo "  stop    - Остановить Comet Cursor"
        echo "  restart - Перезапустить Comet Cursor"
        echo "  status  - Проверить статус Comet Cursor"
        exit 1
        ;;
esac