# การ์ดสินค้า Catalog — issue #40

ขอบเขต: ใช้หน้าตาการ์ด Preview และ labels ที่ผู้ใช้ปรับไว้ แยกเป็น partial
`catalog/card` และ CSS ที่ใช้ซ้ำได้ โดยไม่สร้าง product/auction model ใหม่

- รับ `lot` ที่มีชื่อ หมวดหมู่ เวลาเริ่มและปิด, `status`, `auction_type`
  (ใช้ค่า domain `english` หรือ `sealed_first_price`), `image_path` และ `detail_path` ที่ไม่บังคับ
- รูปมี alt text และ lazy loading; หากไม่มีรูปหรือโหลดไม่ได้ แสดงภาพสำรองในพื้นที่ขนาดคงที่
- แสดงชื่อ หมวดหมู่ label สถานะ และ label วิธีประมูลคู่กันตามหน้าตาที่ผู้ใช้เลือก
- แสดงเวลาเริ่ม/ปิดใน Asia/Bangkok พร้อม datetime แบบ ISO
- หากมี path รายละเอียดภายในแอป แสดงชื่อเป็นลิงก์; ถ้ายังไม่มี แสดงข้อความปกติ
- รับเฉพาะ image/detail paths ภายในแอป ปฏิเสธ scheme และ protocol-relative paths
- Grid 3 คอลัมน์บนจอใหญ่ 2 บนแท็บเล็ต และ 1 บนมือถือ ชื่อยาวต้องตัดบรรทัดได้
- ตรวจ rendering ด้วย Rails view tests รวม escaping และการไม่สร้างลิงก์อันตราย

แนวทาง: Rails partial เหมาะกับโครงสร้าง Rails เดิม ไม่ต้องเพิ่ม component library
การเชื่อมฐานข้อมูลและหน้ารายละเอียดจริงยังขึ้นกับงานเจ้าของ model/route
