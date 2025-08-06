import http from 'k6/http';
import { check } from 'k6';

export const options = {
  scenarios: {
    constant_rate: {
      executor: 'constant-arrival-rate',
      rate: 10000,        // 초당 1000 요청 
      timeUnit: '1s',
      duration: '300s',
      preAllocatedVUs: 50,
      maxVUs: 100,
    },
  },
};

export default function () {
  const response = http.get('http://localhost:8080/hello');
  
  check(response, {
    '서비스 응답 OK': (r) => r.status === 200,
    '응답시간 확인': (r) => {
      console.log(`응답시간: ${r.timings.duration}ms`);
      return true;
    },
  });
  
  console.log(`응답 내용: ${response.body}`);
} 