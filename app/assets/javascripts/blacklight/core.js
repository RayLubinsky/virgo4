// app/assets/javascripts/blacklight/core.js
//
// This code is essentially unchanged from the original Blacklight source.
// @see https://github.com/projectblacklight/blacklight/blob/v7.0.1/app/javascript/blacklight/core.js

Blacklight = function() {
    var buffer = new Array;
    return {
        onLoad: function(func) {
            buffer.push(func);
        },

        activate: function() {
            for (var i = 0; i < buffer.length; i++) {
                buffer[i].call();
            }
        },

        listeners: function() {
            var listeners = [];
            if (typeof Turbolinks !== 'undefined' && Turbolinks.supported) {
                // Turbolinks 5
                if (Turbolinks.BrowserAdapter) {
                    listeners.push('turbolinks:load');
                } else {
                    // Turbolinks < 5
                    listeners.push('page:load', 'DOMContentLoaded');
                }
            } else {
                listeners.push('DOMContentLoaded');
            }

            return listeners;
        }
    };
}();

// Turbolinks triggers page:load events on page transition.
// If app isn't using turbolinks, this event will never be triggered, no prob.
Blacklight.listeners().forEach(function(listener) {
    document.addEventListener(listener, function() {
        Blacklight.activate();
    });
});

$('.no-js').removeClass('no-js').addClass('js');
