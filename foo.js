(function(globals) {

  var STREAMING_USERNAME = "yourUsername",
      STREAMING_PW       = "yourPassword";

  var tweetTemplate = "\
    <div class='tweet' id='tweet-{{id}}'>\
      <img src='{{#user}}{{profile_image_url}}{{/user}}' />\
      <p class='text'>\
        {{{text}}}<span class='timestamp'>{{created_at}}</span>\
      </p>\
    </div>";

  var globe = DAT.Globe(document.getElementById('container'));
  var $body = $("body");

  var streamContainer = $("<div id='firehose-stream'></div>", document);
  streamContainer.appendTo($('body'));
  streamContainer.flash({
    swf: '/russ/StreamProxy.swf',
    height: 1,
    width: 1
  });

  streamContainer.flash(function() {
    console.info("attempting to connect to streams...")
    var that = this;
    setTimeout(function() {
      that.connect(1, "http://stream.twitter.com/1/statuses/filter.json?locations=-180,-90,180,90", STREAMING_USERNAME, STREAMING_PW);
    }, 100);
  });

  function once(fn) {
    var count = 0;
    return function() {
      if (count === 0) {
        count++;
        fn.apply(window, arguments);
      }
    };
  }

  var showTweet = once(function(tweet) {
    tweet.created_at = twttr.helpers.timeAgo(tweet.created_at, false);

    var tweetHtml = Mustache.to_html(tweetTemplate, tweet);
    $body.append(tweetHtml);
  });

  var STOP = false,
      BUFFER_MAX = 100,
      MAG_MULTIPLIER = 10,
      isSpinning = false,
      magnitudes = {},
      points = {},
      flushCount = 1,
      // tweets = [],
      bufferCount = 0;

  globals.streamStop = function() {
    STOP = true;
  };

  globals.streamConnected = function() {
    console.info("connected");
  };

  globals.streamError = function(err) {
    console.info(err);
  };

  globals.connectionTimout = function() {
    console.info("connection timed out");
  };

  globals.socketTimout = function() {
    console.info("socket timed out");
  };

  globals.connectionError = function() {
    console.info("connection error: ", arguments);
  };

  globals.streamEvent = function(streamEvent) {
    if (STOP) {
      return;
    }

    var coordinates, lat, lng, key, magnitude;

    var tweet = JSON.parse(decodeURIComponent(streamEvent));
    if (tweet.coordinates && tweet.coordinates.type === "Point") {
      coordinates = tweet.coordinates.coordinates;

      lng = coordinates[0];
      lat = coordinates[1];
      key = ""+Math.round(lat)+Math.round(lng);

      if (points[key]) {
        points[key][2] += MAG_MULTIPLIER;
      } else {
        points[key] = [lat, lng, MAG_MULTIPLIER];
      }

      if (bufferCount < BUFFER_MAX) {
        // tweets.push(tweet);
        bufferCount++;
        //buffer.push.apply(buffer, [lat, lng, magnitude/(globals.flushCount*BUFFER_MAX)]);
      } else {
        if (!isSpinning) {
          isSpinning = true;
          globe.spin();
        }

        // showTweet(tweets[Math.round(Math.random()*tweets.length) - 1]);

        globe.addData(points, {
          format: "magnitude",
          animated: true,
          dataAsObject: true
        });
        globe.createPoints();

        globals.flushCount++;
        // tweets = [];
        bufferCount = 0;
      }
    }
  };

  globe.animate();
  globe.spin();
  // globals.$title = $("#title");
  globals.BUFFER_MAX = BUFFER_MAX;
  globals.flushCount = flushCount;
  globals.globe = globe;

}(window));