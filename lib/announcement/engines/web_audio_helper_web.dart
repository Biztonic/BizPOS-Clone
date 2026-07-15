import 'dart:js' as js;

void playWebBeep(String soundType, double volume) {
  try {
    double freq = 800;
    double duration = 0.1;
    String type = 'sine';

    if (soundType == 'chime') {
      freq = 1000;
      duration = 0.3;
      type = 'triangle';
    } else if (soundType == 'click') {
      freq = 1200;
      duration = 0.05;
      type = 'square';
    }

    js.context.callMethod('eval', [
      '''
      (function() {
        var AudioContext = window.AudioContext || window.webkitAudioContext;
        if (!AudioContext) return;
        var ctx = new AudioContext();
        var osc = ctx.createOscillator();
        var gain = ctx.createGain();
        osc.connect(gain);
        gain.connect(ctx.destination);
        osc.type = "$type";
        osc.frequency.setValueAtTime($freq, ctx.currentTime);
        gain.gain.setValueAtTime($volume * 0.1, ctx.currentTime);
        gain.gain.exponentialRampToValueAtTime(0.01, ctx.currentTime + $duration);
        osc.start(ctx.currentTime);
        osc.stop(ctx.currentTime + $duration);
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
          gain.gain.setValueAtTime($volume * 0.15, time);
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
