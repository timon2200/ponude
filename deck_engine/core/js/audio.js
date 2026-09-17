/**
 * audio.js — Zero-Dependency Mechanical Sound Synthesizer (Web Audio API)
 */
let soundEnabled = false;
let audioCtx = null;

export function initAudio() {
  if (!audioCtx) {
    audioCtx = new (window.AudioContext || window.webkitAudioContext)();
  }
  if (audioCtx.state === 'suspended') {
    audioCtx.resume();
  }
}

export function playTick(direction = 'forward') {
  if (!soundEnabled) return;
  try {
    initAudio();
    const osc = audioCtx.createOscillator();
    const gain = audioCtx.createGain();
    osc.type = 'sine';
    const now = audioCtx.currentTime;
    const freq = direction === 'forward' ? 1200 : 900;
    osc.frequency.setValueAtTime(freq, now);
    osc.frequency.exponentialRampToValueAtTime(320, now + 0.032);
    gain.gain.setValueAtTime(0.045, now);
    gain.gain.exponentialRampToValueAtTime(0.0001, now + 0.032);
    osc.connect(gain);
    gain.connect(audioCtx.destination);
    osc.start(now);
    osc.stop(now + 0.032);
  } catch (e) {}
}

export function toggleSound() {
  soundEnabled = !soundEnabled;
  if (soundEnabled) initAudio();
  const iconOn = document.getElementById('soundIconOn');
  const iconOff = document.getElementById('soundIconOff');
  const label = document.getElementById('soundLabel');
  if (iconOn && iconOff && label) {
    iconOn.style.display = soundEnabled ? 'inline-block' : 'none';
    iconOff.style.display = soundEnabled ? 'none' : 'inline-block';
    label.textContent = soundEnabled ? 'Sound: ON' : 'Sound: OFF';
  }
  if (soundEnabled) playTick('forward');
}

window.toggleSound = toggleSound;
window.playTick = playTick;
