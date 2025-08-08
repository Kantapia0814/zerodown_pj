while true; do
  echo "=== $(date) ==="
  RESPONSE=$(curl -s -w "\n%{http_code} %{time_total}\n" http://localhost:8080/hello)
  # RESPONSE의 마지막 두 줄이 상태코드/시간, 그 위가 본문
  echo "$RESPONSE"
  sleep 0.00001
done | tee -a test_log.txt