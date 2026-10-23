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
      setStatus('Please choose a photo or image file (JPG, PNG, or another browser-supported image).', 'error');
      return;
    }
    if (file.size > 15 * 1024 * 1024) {
      currentImage = null;
      byId('run-ocr').disabled = true;
      byId('make-pdf').disabled = true;
      setStatus('This image is larger than 15 MB. Resize it and upload again for reliable browser processing.', 'error');
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
    setStatus('Image selected. OfficeFlow is starting automatic text recognition…');
    recognizeImage();
  });

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