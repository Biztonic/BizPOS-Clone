import 'dart:convert';
import 'dart:js' as js;
import 'dart:typed_data';

void playWebBeep(String soundType, double volume) {
  try {
    js.context.callMethod('eval', [
      '''
      (function() {
        var AudioContext = window.AudioContext || window.webkitAudioContext;
        if (!AudioContext) return;
        var ctx = new AudioContext();
        
        var playOsc = function(type, freq, time, dur, gainVal, freqEnd) {
          var osc = ctx.createOscillator();
          var gain = ctx.createGain();
          osc.connect(gain);
          gain.connect(ctx.destination);
          
          osc.type = type;
          osc.frequency.setValueAtTime(freq, time);
          if (freqEnd && freqEnd > 0) {
            osc.frequency.exponentialRampToValueAtTime(freqEnd, time + dur);
          }
          
          gain.gain.setValueAtTime(gainVal * $volume * 0.5, time);
          gain.gain.exponentialRampToValueAtTime(0.01, time + dur);
          
          osc.start(time);
          osc.stop(time + dur);
        };

        var now = ctx.currentTime;
        var type = "$soundType";
        
        switch(type) {
          // CLICKS (1-5)
          case "1": // Standard Click
            playOsc("sine", 1200, now, 0.06, 0.8);
            break;
          case "2": // Tech Click
            playOsc("square", 1500, now, 0.04, 0.4);
            break;
          case "3": // High Tick
            playOsc("triangle", 2200, now, 0.03, 0.9);
            break;
          case "4": // Wood Click
            playOsc("triangle", 600, now, 0.09, 0.8);
            break;
          case "5": // Pop Click
            playOsc("sine", 400, now, 0.06, 0.9, 1000);
            break;
            
          // BEEPS (6-10)
          case "6": // Standard Beep
            playOsc("sine", 800, now, 0.12, 0.8);
            break;
          case "7": // High Beep
            playOsc("sine", 1300, now, 0.12, 0.8);
            break;
          case "8": // Low Beep
            playOsc("sine", 450, now, 0.18, 0.9);
            break;
          case "9": // Double Beep
            playOsc("sine", 800, now, 0.08, 0.7);
            playOsc("sine", 800, now + 0.10, 0.08, 0.7);
            break;
          case "10": // Triple Beep
            playOsc("sine", 900, now, 0.06, 0.7);
            playOsc("sine", 900, now + 0.08, 0.06, 0.7);
            playOsc("sine", 900, now + 0.16, 0.06, 0.7);
            break;
            
          // CHIMES (11-15)
          case "11": // Ascending Chime
            playOsc("sine", 523.25, now, 0.1, 0.7);
            playOsc("sine", 659.25, now + 0.08, 0.1, 0.7);
            playOsc("sine", 783.99, now + 0.16, 0.1, 0.7);
            break;
          case "12": // Descending Chime
            playOsc("sine", 783.99, now, 0.1, 0.7);
            playOsc("sine", 659.25, now + 0.08, 0.1, 0.7);
            playOsc("sine", 523.25, now + 0.16, 0.1, 0.7);
            break;
          case "13": // Major Chord Chime
            playOsc("sine", 523.25, now, 0.25, 0.4);
            playOsc("sine", 659.25, now, 0.25, 0.4);
            playOsc("sine", 783.99, now, 0.25, 0.4);
            break;
          case "14": // Ding Dong
            playOsc("sine", 587.33, now, 0.18, 0.8);
            playOsc("sine", 493.88, now + 0.20, 0.35, 0.8);
            break;
          case "15": // Ring Chime
            playOsc("sine", 1600, now, 0.45, 0.8);
            break;
            
          // SFX & SYNTHS (16-20)
          case "16": // Sci-Fi Sweep Up
            playOsc("sine", 500, now, 0.22, 0.8, 1800);
            break;
          case "17": // Sci-Fi Sweep Down
            playOsc("sine", 1800, now, 0.22, 0.8, 500);
            break;
          case "18": // Retro Laser
            playOsc("sawtooth", 2200, now, 0.14, 0.3, 100);
            break;
          case "19": // Alert Ping
            playOsc("triangle", 1600, now, 0.32, 0.8);
            break;
          case "20": // Digital Alarm Pulse
            playOsc("square", 1000, now, 0.08, 0.3);
            playOsc("square", 1000, now + 0.12, 0.08, 0.3);
            break;
            
          // LEGACY FALLBACKS
          case "chime":
            playOsc("triangle", 1000, now, 0.3, 0.8);
            break;
          case "click":
          default:
            playOsc("square", 1200, now, 0.05, 0.4);
            break;
        }
      })();
      '''
    ]);
  } catch (_) {}
}

void playWebSynthSound(String assetPath, double volume) {
  try {
    double duration = 0.15;
    double freq1 = 800;
    double freq2 = 0; 

    if (assetPath.contains('payment_success')) {
      freq1 = 523.25; 
      freq2 = 659.25; 
      duration = 0.4;
    } else if (assetPath.contains('payment_failed') || assetPath.contains('warning')) {
      freq1 = 300;
      duration = 0.3;
    } else if (assetPath.contains('item_added')) {
      freq1 = 987.77; 
      duration = 0.08;
    }

    js.context.callMethod('eval', [
      '''
      (function() {
        var AudioContext = window.AudioContext || window.webkitAudioContext;
        if (!AudioContext) return;
        var ctx = new AudioContext();
        
        var playTone = function(freq, time, dur) {
          var osc = ctx.createOscillator();
          var gain = ctx.createGain();
          osc.connect(gain);
          gain.connect(ctx.destination);
          osc.frequency.setValueAtTime(freq, time);
          gain.gain.setValueAtTime($volume * 0.40, time); // Louder alert sounds
          gain.gain.exponentialRampToValueAtTime(0.01, time + dur);
          osc.start(time);
          osc.stop(time + dur);
        };
        
        if ($freq2 > 0) {
          playTone($freq1, ctx.currentTime, $duration / 2);
          playTone($freq2, ctx.currentTime + $duration / 2, $duration / 2);
        } else {
          playTone($freq1, ctx.currentTime, $duration);
        }
      })();
      '''
    ]);
  } catch (_) {}
}

void playWebAudioBytes(Uint8List bytes, double volume) {
  try {
    final base64Str = base64Encode(bytes);
    js.context.callMethod('eval', [
      '''
      (function() {
        var base64Data = "$base64Str";
        var binaryString = window.atob(base64Data);
        var len = binaryString.length;
        var bytesArray = new Uint8List(len);
        for (var i = 0; i < len; i++) {
          bytesArray[i] = binaryString.charCodeAt(i);
        }
        var blob = new Blob([bytesArray.buffer], {type: 'audio/mpeg'});
        var url = URL.createObjectURL(blob);
        
        var audio = new Audio(url);
        audio.volume = $volume;
        audio.play();
      })();
      '''
    ]);
  } catch (_) {}
}
