/**
 * 더나은세무회계 종합소득세 신고 폼 수신기
 * Google Apps Script — Google Sheets + Drive 자동 저장
 *
 * ▶ 배포 방법 (README.md 참고)
 *   1) 구글 스프레드시트를 하나 새로 만든다 (예: "더나은_2026종소세_접수")
 *   2) 확장 프로그램 → Apps Script → 이 코드 붙여넣기
 *   3) 저장 → 배포 → 새 배포 → 유형: 웹 앱
 *      - 다음 사용자 인증으로 실행: 나
 *      - 액세스 권한: 모든 사용자
 *   4) 발급된 웹 앱 URL을 index.html의 CONFIG.GAS_ENDPOINT 에 붙여넣기
 *   5) index.html의 CONFIG.DEMO_MODE 를 false로 변경
 */

// ── 설정값 ───────────────────────────────────
const CONFIG = {
  // 시트 탭 이름 (없으면 자동 생성)
  SHEET_SUBMIT: '신고신청',
  SHEET_CTA:    'CTA클릭',
  // 업로드 파일 저장할 Drive 폴더 이름(없으면 루트에 생성)
  DRIVE_FOLDER: '더나은_접수파일',
  // 허용 출처(CORS 방지). '*'는 누구나 호출 가능. 운영 시 도메인 고정 권장.
  ALLOW_ORIGIN: '*'
};

// ── 메인 엔트리 ───────────────────────────────
function doPost(e) {
  try {
    const body = JSON.parse(e.postData.contents || '{}');
    if (body.type === 'submission') return _handleSubmission(body);
    if (body.type === 'cta_click')  return _handleCtaClick(body);
    return _json({ ok: false, error: 'unknown type' });
  } catch (err) {
    return _json({ ok: false, error: String(err) });
  }
}

function doGet() {
  return _json({ ok: true, msg: '더나은세무회계 접수 엔드포인트 동작중' });
}

// ── 신고 신청 처리 ────────────────────────────
function _handleSubmission(body) {
  const d = body.data || {};
  const files = body.files || [];

  // 1) 파일들을 Drive 폴더에 저장
  const folder = _ensureFolder(CONFIG.DRIVE_FOLDER);
  // 의뢰자별 서브폴더
  const safeName = (d.targetName || 'unknown').replace(/[^\w가-힣]/g, '_');
  const ts = Utilities.formatDate(new Date(), 'Asia/Seoul', 'yyyyMMdd_HHmmss');
  const sub = folder.createFolder(`${ts}_${safeName}`);

  const fileLinks = [];
  files.forEach(f => {
    try {
      const bytes = Utilities.base64Decode(f.data);
      const blob  = Utilities.newBlob(bytes, f.mime || 'application/octet-stream', `${f.docKey}_${f.name}`);
      const gf    = sub.createFile(blob);
      gf.setSharing(DriveApp.Access.ANYONE_WITH_LINK, DriveApp.Permission.VIEW);
      fileLinks.push(`[${f.docKey}] ${f.name} → ${gf.getUrl()}`);
    } catch (err) {
      fileLinks.push(`[${f.docKey}] ${f.name} (저장실패: ${err})`);
    }
  });

  // 2) 시트에 행 추가
  const sheet = _ensureSheet(CONFIG.SHEET_SUBMIT, [
    '접수일시(KST)', '대상자성함', '의뢰자성함', '연락처', '업종구분',
    '주민번호(마스킹)', '홈택스ID', '홈택스PW제출여부',
    '부양가족(JSON)', '소득종류', '기타소득',
    '진단결과', '진단응답(JSON)',
    '동의_필수1', '동의_필수2', '동의_마케팅',
    '업로드폴더', '파일목록',
    'UserAgent'
  ]);

  sheet.appendRow([
    Utilities.formatDate(new Date(), 'Asia/Seoul', 'yyyy-MM-dd HH:mm:ss'),
    d.targetName || '', d.requesterName || '', d.phone || '', d.bizType || '',
    d.rrnMasked || '', d.hometaxId || '', d.hometaxPwProvided || 'N',
    d.dependents || '[]', d.incomeTypes || '', d.incomeEtc || '',
    d.quizResult || '', d.quizAnswers || '{}',
    d.agree1 ? 'Y' : 'N', d.agree2 ? 'Y' : 'N', d.agree3 ? 'Y' : 'N',
    sub.getUrl(), fileLinks.join('\n'),
    d.userAgent || ''
  ]);

  // 3) 이메일 알림 (선택) ── 세무사 이메일로 즉시 알림
  // _notifyEmail('your@email.com', d);

  return _json({ ok: true, folder: sub.getUrl() });
}

// ── CTA 클릭 로깅 ─────────────────────────────
function _handleCtaClick(body) {
  const sheet = _ensureSheet(CONFIG.SHEET_CTA, [
    '시각(KST)', '진입점', '진단결과', '진단응답(JSON)'
  ]);
  sheet.appendRow([
    Utilities.formatDate(new Date(), 'Asia/Seoul', 'yyyy-MM-dd HH:mm:ss'),
    body.from || '', body.quizResult || '', JSON.stringify(body.quizAnswers || {})
  ]);
  return _json({ ok: true });
}

// ── 유틸 ──────────────────────────────────────
function _ensureSheet(name, headers) {
  const ss = SpreadsheetApp.getActiveSpreadsheet();
  let s = ss.getSheetByName(name);
  if (!s) {
    s = ss.insertSheet(name);
    s.appendRow(headers);
    s.setFrozenRows(1);
    s.getRange(1, 1, 1, headers.length).setFontWeight('bold').setBackground('#E6F4DB');
  }
  return s;
}

function _ensureFolder(name) {
  const it = DriveApp.getFoldersByName(name);
  if (it.hasNext()) return it.next();
  return DriveApp.createFolder(name);
}

function _json(obj) {
  return ContentService
    .createTextOutput(JSON.stringify(obj))
    .setMimeType(ContentService.MimeType.JSON);
}

// (선택) 세무사 이메일 알림
function _notifyEmail(to, d) {
  const subject = `[접수] ${d.targetName} (${d.bizType}) 종합소득세 신고 신청`;
  const body =
`새 신고대리 신청이 접수되었습니다.

• 대상자: ${d.targetName}
• 연락처: ${d.phone}
• 업종: ${d.bizType}
• 진단결과: ${d.quizResult}
• 소득종류: ${d.incomeTypes}

스프레드시트에서 상세 확인하세요.`;
  MailApp.sendEmail(to, subject, body);
}
