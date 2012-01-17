(function() {

  window.twttr = window.twttr || {};
  function _(str, subs) {
    return Mustache.to_html(str, subs);
  }

  twttr.helpers = {
    timeWords: {
      longForm: {
        singular: {
         now: "now",
         seconds: "{{one}} second ago",
         minutes: "{{one}} minute ago",
         hours: "{{one}} hour ago",
         days: "{{one}} day ago"
        },
        plural: {
          now: "now",
          seconds: "{{plural_number}} seconds ago",
          minutes: "{{plural_number}} minutes ago",
          hours: "{{plural_number}} hours ago",
          days: "{{plural_number}} days ago"
        }
      },
      shortForm: {
        singular: {
          now: "now",
          seconds: "{{one}} sec",
          minutes: "{{one}} min",
          hours: "{{one}} hr",
          days: "{{one}} day"
        },
        plural: {
          now: "now",
          seconds: "{{plural_number}} sec",
          minutes: "{{plural_number}} mins",
          hours: "{{plural_number}} hrs",
          days: "{{plural_number}} days"
        }
      }
    },

    dates: {
      months: ['Jan', 'Feb', 'Mar', 'Apr', 'May', 'Jun',
               'Jul', 'Aug', 'Sep', 'Oct', 'Nov', 'Dec'],

      dates: ['1st', '2nd', '3rd', '4th', '5th', '6th',
              '7th', '8th', '9th', '10th', '11th', '12th',
              '13th', '14th', '15th', '16th', '17th', '18th', '19th',
              '20th', '21st', '22nd', '23rd', '24th', '25th',
              '26th', '27th', '28th', '29th', '30th', '31st']
    },

    parseDateString: function(dateString) {
      var then = new Date(dateString);

      // protect against null
      if ($.browser.msie && dateString) {
        // IE can't parse these crazy Ruby dates
        then = new Date(Date.parse(dateString.replace(/( \+)/, ' UTC$1')));
      }

      return +then;
    },

    prettyTime: function(time) {
      var d = new Date(time),
          params = {
            month: _(twttr.helpers.dates.months[d.getMonth()]),
            hours24: d.getHours(),
            hours12: (d.getHours() % 12) || 12,
            minutes: d.getMinutes().toString().replace(/^(\d)$/, "0$1"),
            amPm: d.getHours() < 12 ? _("AM") : _("PM"),
            date: _(twttr.helpers.dates.dates[d.getDate() - 1])
          };

      return _("{{hours12}}:{{minutes}} {{amPm}} {{month}} {{date}}", params);
    },

    prettyTimeFromString: function(dateString) {
      return twttr.helpers.prettyTime(twttr.helpers.parseDateString(dateString));
    },

    timeAgoFromString: function(dateString, longForm, includeTime) {
      return twttr.helpers.timeAgo(twttr.helpers.parseDateString(dateString), longForm, includeTime);
    },

    timeAgo: function(time, longForm, includeTime) {
      var words = twttr.helpers.timeWords[longForm ? "longForm" : "shortForm"];
      var rightNow = new Date;
      var then = new Date(time);
      var diff = rightNow - then;

      var second = 1000,
          minute = second * 60,
          hour = minute * 60,
          day = hour * 24,
          week = day * 7,
          result,
          word,
          ret;

      if (isNaN(diff) || diff < 0) {
        return ""; // return blank string if unknown
      }

      if (diff < second * 3) {
        // within 2 seconds
        result = "";
        word = "now";
        includeTime = false;
      } else if (diff < minute) {
        result = Math.floor(diff / second);
        word = "seconds";
        includeTime = false;
      } else if (diff < hour) {
        result = Math.floor(diff / minute);
        word = "minutes";
        includeTime = false;
      } else if (diff < day) {
        result = Math.floor(diff / hour);
        word = "hours";
        includeTime = false;
      } else if (diff < day * 365) {
        ret = _("{{date}} {{month}}", {
          date: then.getDate(),
          month: _(twttr.helpers.dates.months[then.getMonth()])
        });
      } else {
        ret = _("{{date}} {{month}} {{year}}", {
          date: then.getDate(),
          month: _(twttr.helpers.dates.months[then.getMonth()]),
          year: then.getFullYear().toString().slice(2)
        });
      }

      if (!ret) {
        if (result === 1) {
          words = words.singular;
        } else {
          words = words.plural;
        }

        ret = _(words[word], { one: result, plural_number: result });
      }

      if (includeTime) {
        ret += _(" at {{time}}", {time: then.toTimeString().split(":").slice(0,2).join(":")});
      }

      return ret;
    },

    // Turns a profile image url into a different, specified size
    // Assumes input comes straight from the API (ends in _normal before optional extension)
    transformProfileImageUrl: function (profileImageUrl, size) {
      if (typeof(profileImageUrl) === "string") {
        return profileImageUrl;
      }

      // for default images, we don't have a "full-size" copy, only "bigger" (72x72)
      if (!size && profileImageUrl.match(/default_profile_\d_normal.png$/)) {
        size = "bigger";
      }

      // $1 === ".png" or nothing, etc.
      var replacementRegex = /_normal(\..*)?$/i;


      if (size) {
        return profileImageUrl.replace(replacementRegex, "_" + size + "$1");
      } else {
        return profileImageUrl.replace(replacementRegex, "$1");
      }
    },

    truncate: function(str, maxLength, truncateString) {
      truncateString = truncateString || "&hellip;";
      var truncateStringLength = $("<div/>").html(truncateString).text().length;

      if (str.length > maxLength) {
        str = str.slice(0, maxLength - truncateStringLength) + truncateString;
      }

      return str;
    }
  };

}());