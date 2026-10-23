document.addEventListener('DOMContentLoaded', function () {
  const byId = id => document.getElementById(id);
  const panel = byId('scan-panel');
  if (!panel) return;

  let currentImage = null;
  let currentUrl = '';
  let recognitionWorker = null;
  let recognitionRun = 0;

  const setStatus = (message, kind = 'neutral') => {
    const node = byId('scan-status');
    node.textContent = message;
    node.className = 'text-sm mt-3 ' + (kind === 'error' ? 'text-red-700' : kind === 'success' ? 'text-green-700' : 'text-gray-600');
  };

  byId('open-scan').addEventListener('click', () => panel.classList.remove('hidden'));
  byId('close-scan').addEventListener('click', () => panel.classList.add('hidden'));

  function suggest(text) {
    const value = String(text || '').toLowerCase();
    if (/invoice|payment|budget|payroll|receipt|financial|tax/.test(value)) return 'Finance';
    if (/employee|leave request|recruitment|staff|payslip|disciplinary/.test(value)) return 'HR';
    if (/contract|agreement|lease/.test(value)) return 'Contracts';
    if (/legal|court|compliance|affidavit/.test(value)) return 'Legal';
    if (/tender|supplier|purchase order|quotation/.test(value)) return 'Procurement';
    if (/policy|handbook|procedure/.test(value)) return 'Policies';
    if (/security|network|password|server/.test(value)) return 'IT';
    return 'General';
  }

  async function getWorker() {
    if (!window.Tesseract) {
      await new Promise((resolve, reject) => {
        const script = document.createElement('script');
        script.src = 'https://cdn.jsdelivr.net/npm/tesseract.js@5/dist/tesseract.min.js';
        script.onload = resolve;
        script.onerror = () => reject(new Error('The handwriting recognition library could not be loaded.'));
        document.head.appendChild(script);
      });
    }
    if (!recognitionWorker) {
      recognitionWorker = await Tesseract.createWorker('eng', 1, {
        logger: event => {
          if (event.status === 'recognizing text' && event.progress != null) {
            setStatus('Reading the image… ' + Math.round(event.progress * 100) + '% complete. Keep this window open.');
          } else if (event.status) {
            setStatus('Preparing handwriting recognition… ' + event.status + '…');
          }
        }
      });
    }
    return recognitionWorker;
  }

  async function recognizeImage() {
    if (!currentImage) return;
    const runId = ++recognitionRun;
    const button = byId('run-ocr');
    button.disabled = true;
    byId('download-text').disabled = true;
    byId('ocr-text').value = '';
    setStatus('Starting handwriting recognition. This can take a little while for a clear, full-page image.');
    try {
      const worker = await getWorker();
      if (runId !== recognitionRun) return;
      const result = await worker.recognize(currentImage);
      if (runId !== recognitionRun) return;
      const text = String(result.data && result.data.text || '').trim();
      byId('ocr-text').value = text;
      byId('scan-folder').value = suggest(text);
      byId('download-text').disabled = !text;
      const confidence = Number(result.data && result.data.confidence);
      if (text) {
        const confidenceText = Number.isFinite(confidence) ? ' Recognition confidence estimate: ' + Math.round(confidence) + '%.' : '';
        setStatus('Conversion complete. The recognized words are now editable typed text below. Suggested folder: ' + byId('scan-folder').value + '.' + confidenceText + ' Please proofread handwriting before using the text officially.', 'success');
      } else {
        setStatus('No text was detected. Try a sharper, brighter, straight-on image with the full page visible, then choose Recognize Again.', 'error');
      }
    } catch (error) {
      setStatus((error && error.message ? error.message : 'Text recognition failed.') + ' Check your internet connection and try again.', 'error');
    } finally {
      if (runId === recognitionRun) button.disabled = !currentImage;
    }
  }

  byId('scan-file').addEventListener('change', function () {
    const file = this.files && this.files[0];
    if (!file) return;
    if (!file.type.startsWith('image/')) {
      currentImage = null;
      byId('run-ocr').disabled = true;
      byId('make-pdf').disabled = true;
      byId('save-document').disabled = true;
      setStatus('Please choose a JPG, PNG or WEBP image.', 'error');
      return;
    }
    if (file.size > 10 * 1024 * 1024) {
      currentImage = null;
      byId('run-ocr').disabled = true;
      byId('make-pdf').disabled = true;
      byId('save-document').disabled = true;
      setStatus('This image is larger than 10 MB. Resize it and upload again.', 'error');
      return;
    }
    currentImage = file;
    recognitionRun++;
    if (currentUrl) URL.revokeObjectURL(currentUrl);
    currentUrl = URL.createObjectURL(file);
    byId('scan-preview').src = currentUrl;
    byId('scan-preview').classList.remove('hidden');
    byId('scan-name').value = file.name.replace(/\.[^.]+$/, '');
    byId('ocr-text').value = '';
    byId('download-text').disabled = true;
    byId('run-ocr').disabled = false;
    byId('make-pdf').disabled = false;
    byId('save-document').disabled = false;
    byId('save-document').textContent = 'Save to OfficeFlow';
    setStatus('Image selected. OfficeFlow is starting automatic text recognition…');
    recognizeImage();
  });


  async function saveDocument() {
    const button = byId('save-document');
    const name = byId('scan-name').value.trim();
    const folder = byId('scan-folder').value;
    if (!currentImage) { setStatus('Choose a scan before saving.', 'error'); return; }
    if (!name) { byId('scan-name').focus(); setStatus('Enter a document name before saving.', 'error'); return; }
    if (!['image/jpeg','image/png','image/webp'].includes(currentImage.type)) {
      setStatus('Use a JPG, PNG or WEBP image. These are the formats allowed by secure document storage.', 'error'); return;
    }
    if (currentImage.size > 10 * 1024 * 1024) {
      setStatus('This file exceeds the 10 MB secure storage limit. Resize it and try again.', 'error'); return;
    }
    button.disabled = true;
    const previousLabel = button.textContent;
    button.textContent = 'Saving…';
    setStatus('Checking your session and organization permissions…');
    let uploadedPath = '';
    try {
      if (window.OOES_AUTH) {
        await OOES_AUTH.ready;
        if (!OOES_AUTH.isLoggedIn()) throw new Error('Your session has expired. Sign in again, then retry saving.');
      }
      const { data: authData, error: authError } = await supabase.auth.getUser();
      if (authError) throw authError;
      const user = authData && authData.user;
      if (!user) throw new Error('You must be signed in to save documents.');
      const { data: orgId, error: orgError } = await supabase.rpc('fn_current_org');
      if (orgError) throw orgError;
      if (!orgId) throw new Error('OfficeFlow could not identify your organization. Please sign in again or contact your administrator.');
      const safeName = name.replace(/[^a-zA-Z0-9._-]+/g, '-').replace(/^-+|-+$/g, '').slice(0,100) || 'scanned-document';
      uploadedPath = String(orgId) + '/' + user.id + '/' + Date.now() + '-' + crypto.randomUUID() + '-' + safeName + '.' + (currentImage.type === 'image/jpeg' ? 'jpg' : currentImage.type === 'image/png' ? 'png' : 'webp');
      setStatus('Uploading the scan to private organization storage…');
      const { error: uploadError } = await supabase.storage.from('officeflow-documents').upload(uploadedPath, currentImage, { contentType: currentImage.type, upsert: false });
      if (uploadError) throw uploadError;
      setStatus('File uploaded. Registering document metadata…');
      const { error: insertError } = await supabase.from('documents').insert({
        name: name,
        type: currentImage.type,
        size: String(currentImage.size),
        folder: folder,
        uploaded_by: user.email || user.id,
        url: uploadedPath,
        owner_id: user.id,
        organization_id: orgId
      });
      if (insertError) {
        await supabase.storage.from('officeflow-documents').remove([uploadedPath]);
        uploadedPath = '';
        throw insertError;
      }
      setStatus('Document saved successfully to your organization’s document register and private storage.', 'success');
      button.textContent = 'Saved to OfficeFlow';
      await window.loadOfficeFlowDocuments?.();
      const refreshButton = byId('refresh');
      if (refreshButton) refreshButton.click();
      setTimeout(() => { if (button.isConnected) { button.textContent = previousLabel; button.disabled = !currentImage; } }, 2500);
    } catch (error) {
      setStatus('Could not save document: ' + (error && error.message ? error.message : 'Unknown storage or permission error.') + ' Your scan remains in this window; correct the issue and retry.', 'error');
      button.textContent = previousLabel;
      button.disabled = !currentImage;
    }
  }
  byId('save-document').addEventListener('click', saveDocument);

  byId('run-ocr').addEventListener('click', recognizeImage);

  byId('make-pdf').addEventListener('click', async function () {
    if (!currentImage || !currentUrl) return;
    this.disabled = true;
    try {
      if (!window.jspdf) {
        await new Promise((resolve, reject) => {
          const script = document.createElement('script');
          script.src = 'https://cdn.jsdelivr.net/npm/jspdf@2.5.2/dist/jspdf.umd.min.js';
          script.onload = resolve;
          script.onerror = () => reject(new Error('PDF conversion library could not be loaded.'));
          document.head.appendChild(script);
        });
      }
      const image = new Image();
      image.src = currentUrl;
      await image.decode();
      const pdf = new window.jspdf.jsPDF({ orientation: image.width > image.height ? 'landscape' : 'portrait', unit: 'pt', format: 'a4' });
      const width = pdf.internal.pageSize.getWidth();
      const height = pdf.internal.pageSize.getHeight();
      const scale = Math.min(width / image.width, height / image.height);
      pdf.addImage(image, 'JPEG', (width - image.width * scale) / 2, (height - image.height * scale) / 2, image.width * scale, image.height * scale);
      pdf.save((byId('scan-name').value || 'scanned-document') + '.pdf');
      setStatus('PDF created and downloaded. The original image has not been changed.', 'success');
    } catch (error) {
      setStatus('PDF conversion failed. Try a JPG or PNG image and try again.', 'error');
    } finally {
      this.disabled = !currentImage;
    }
  });

  byId('download-text').addEventListener('click', function () {
    const text = byId('ocr-text').value;
    if (!text.trim()) return;
    const url = URL.createObjectURL(new Blob([text], { type: 'text/plain;charset=utf-8' }));
    const link = document.createElement('a');
    link.href = url;
    link.download = (byId('scan-name').value || 'document') + '-transcript.txt';
    document.body.appendChild(link);
    link.click();
    link.remove();
    setTimeout(() => URL.revokeObjectURL(url), 1000);
  });

  window.addEventListener('beforeunload', () => {
    if (currentUrl) URL.revokeObjectURL(currentUrl);
    if (recognitionWorker) recognitionWorker.terminate().catch(() => {});
  });
});