import http from 'k6/http';
import { check, sleep } from 'k6';

// 테스트 설정
export const options = {
  vus: 10,         // 10명의 가상 사용자
  duration: '30s', // 30초간 실행
};

// 테스트 함수
export default function () {
  // hello-service 테스트
  const response = http.get('http://localhost:8080/hello');
  
  // 응답 검증
  check(response, {
    '상태코드가 200': (r) => r.status === 200,
    '응답시간이 100ms 미만': (r) => r.timings.duration < 100,
    '응답에 Hello가 포함': (r) => r.body && r.body.includes('Hello'),
  });
  
  sleep(1); // 1초 대기
}