package {
  import flash.display.Sprite;
  import flash.events.IOErrorEvent;
  import flash.events.ProgressEvent;
  import flash.events.HTTPStatusEvent;
  import flash.events.SecurityErrorEvent;
  import flash.events.TimerEvent;
  import flash.external.ExternalInterface;

  import flash.net.URLRequest;
  import flash.net.URLRequestHeader;
  import flash.net.URLRequestMethod;
  import flash.net.URLStream;
  import flash.net.URLVariables;

  import mx.utils.Base64Encoder;
  import flash.utils.Timer;
  import com.adobe.serialization.json.JSON;
  import com.adobe.serialization.json.JSONParseError;

  public class StreamProxy extends Sprite {
    // the connection to the streaming API
    private var stream:URLStream;

    //cursor tracking amount of data read from stream
    private var amountRead:int = 0;
    private var isReading:Boolean = false;
    private var streamBuffer:String = "";

    //connection management
    private var connectionTimer:Timer;
    private var transmissionTimer:Timer;
    private var lastTransmissionTime:Date;
    private var backoff:int = 0;
    private var request:URLRequest = null;
    private var streamId:int;

    public function StreamProxy() {
      //username:String, pass:String
      ExternalInterface.addCallback("connect", function(id:int, path:String, username:String, pass:String):void {
        streamId = id;
        request = createBasicAuthRequest(path, username, pass);
        connect();
      });

      ExternalInterface.addCallback("reconnect", function():void {
        reconnect();
      });

      ExternalInterface.addCallback("disconnect", function():void {
        disconnect();
      });
    }

    private function connect():void {
      stream = new URLStream();

      stream.addEventListener(IOErrorEvent.IO_ERROR, errorReceived);
      stream.addEventListener(HTTPStatusEvent.HTTP_STATUS, socketStatusReceived);
      stream.addEventListener(ProgressEvent.PROGRESS, dataReceived);
      stream.addEventListener(SecurityErrorEvent.SECURITY_ERROR, securityErrorHandler);


      connectionTimer = new Timer(5000);
      connectionTimer.addEventListener(TimerEvent.TIMER, connectionTimout);

//      transmissionTimer = new Timer(90000);
//      transmissionTimer.addEventListener(TimerEvent.TIMER, transmissionTimeout);

      connectionTimer.start();
      stream.load(request);
    }

    private function reconnect():void {
      amountRead = 0;
      streamBuffer = "";

      if(stream && stream.connected) {
        disconnect();
      }

      connect();
    }

    private function disconnect():void {
      stream.close();
      stream = null;

      ExternalInterface.call(getStreamPathMethod("streamDisconnected"));
    }

    private function b64encode(s:String):String {
      var encoder:Base64Encoder = new Base64Encoder();
      encoder.encode(s);
      return encoder.toString();
    }

// Basic Auth version
    private function createBasicAuthRequest(path:String, username:String, pass:String):URLRequest {
      ExternalInterface.call("console.warn", path, username, pass);
      var request:URLRequest = new URLRequest(path);
      request.requestHeaders = new Array(new URLRequestHeader("Authorization", "Basic " + b64encode(username + ":" + pass)));
      request.method = URLRequestMethod.POST;
      request.data = 0
      ExternalInterface.call("console.warn", JSON.encode(request));
      return request;
    }

// OAuth version
    private function createOauth2Request(path:String, accessToken:String):URLRequest {
      var request:URLRequest = new URLRequest(path);
      request.method = URLRequestMethod.POST;

      var requestParams:URLVariables = new URLVariables();
      requestParams.oauth_access_token = accessToken;
      request.data = requestParams;
      return request;
    }

    private function createOauthRequest(path:String):URLRequest {
      var request:URLRequest = new URLRequest(path);
      request.method = URLRequestMethod.POST;

      var requestParams:URLVariables = new URLVariables();

      requestParams.oauth_consumer_key="Oef4mCIDHzcFWOxzh5xc8g";
      requestParams.oauth_nonce="406312b92205be7c0414436bc9928494";
      requestParams.oauth_signature="XgJItjLlGqu7OrvIAgRr4knDxss%3D";
      requestParams.oauth_signature_method="HMAC-SHA1";
      requestParams.oauth_timestamp="1304650212";
      requestParams.oauth_token="213845925-e48sOXymDJ0sr1gADGN6nGc3xjuwyj0M4pvFqk31";
      requestParams.oauth_version="1.0";

      request.data = requestParams;
      return request;
    }

    private function getStreamPathMethod(methodName:String):String {
      /*return "twttr.API.util.Stream.streams.s" + streamId + "." + methodName;*/
      return "window." + methodName;
    }

    private function connectionTimout(timerEvent:TimerEvent):void {
      if (!stream.connected) {
        ExternalInterface.call(getStreamPathMethod("connectionTimeout"));
        reconnect();
      }
    }

    private function transmissionTimeout(timerEvent:TimerEvent):void {
      ExternalInterface.call(getStreamPathMethod("socketTimeout"));
      reconnect();
    }

    private function initialBackoff():int {
      var min:int = 20,
          max:int = 40;

      return (int)(min + Math.round((Math.random() * (max - min))));
    }

    private function socketStatusReceived(httpStatus:HTTPStatusEvent):void {
      connectionTimer.stop();
      var code:int = httpStatus.status;

      if (code > 200) {
        ExternalInterface.call(getStreamPathMethod("connectionError"), code, backoff);

        var backoffTimer:Timer = new Timer(backoff);
        backoffTimer.addEventListener(TimerEvent.TIMER, reconnect);
        backoffTimer.start();

        if (backoff == 0) {
          backoff = initialBackoff();
        } else if ((code == 420 && backoff < 240) || (code != 420 && backoff < 120)) {
          backoff *= 2;
        }
      }
    }

    private function log(... arguments):void {
      var args:Array = ["console.log"].concat(arguments);
      ExternalInterface.call.apply(ExternalInterface, args);
    }


    private function encodeStringForTransport(s:String):String {
      return s.split("%").join("%25").split("\\").join("%5c").split("\"").join("%22").split("&").join("%26");
    }

    private function dataReceived(pe:ProgressEvent):void {
       var toRead:Number = pe.bytesLoaded - amountRead;
       var buffer:String = stream.readUTFBytes(toRead);
       amountRead = pe.bytesLoaded;

       // attempt to restart the stream
       var parts:Array;
       if (!isReading) {
         parts = buffer.split(/\n/);
         var firstPart:String = parts[0].replace(/[\s\n]*/, "");
         if (firstPart != "")
           ExternalInterface.call(getStreamPathMethod("streamConnected"), encodeStringForTransport(firstPart));
         buffer = parts.slice(1).join("\n");
         isReading = true;
       }

       // pump the JSON pieces through -- due to actionscript to javascript
       // encoding issues, we have to wrap them funnily
       if ((toRead > 0) && (amountRead > 0)) {
         streamBuffer += buffer;
         parts = streamBuffer.split(/\n/);
         var lastElement:String = parts.pop();
         parts.forEach(function(s:String, i:int, a:Array):void {
           ExternalInterface.call(getStreamPathMethod("streamEvent"), encodeStringForTransport(s));
         });
         streamBuffer = lastElement;
       }
     }


    // parse the incoming data stream -- this will call out to "streamEvent"
    // in javascript with the JSON
/*    private function dataReceived(pe:ProgressEvent):void {
      //didn't timeout so stop timer
      connectionTimer.stop();
      backoff = 0;

      var toRead:Number = pe.bytesLoaded - amountRead;
      var buffer:String = stream.readUTFBytes(toRead);
      amountRead = pe.bytesLoaded;

      // attempt to restart the stream
      var parts:Array;
      if (!isReading) {
        ExternalInterface.call(getStreamPathMethod("streamConnected"), 'pants'); //JSON.decode(firstPart)
        isReading = true;
        transmissionTimer.start();
      }

//      log("data received, toRead=%o, buffer=%o, amountRead=%o, streamBuffer=%o", toRead, buffer, amountRead, streamBuffer);

      // pump the JSON pieces through -- due to actionscript to javascript
      // encoding issues, we have to wrap them funnily
      if (toRead > 0) {
        //reset the transmission timer
        transmissionTimer.reset();
        transmissionTimer.start();

        streamBuffer += buffer;
        parts = streamBuffer.split(/\n/);
        var lastElement:String = parts.pop();
        parts.forEach(function(s:String, i:int, a:Array):void {
          if (s.length > 1) {
            try {
              log("sending element %o", s);
              ExternalInterface.call(getStreamPathMethod("streamEvent"), s);
            } catch(err:Error) {
              ExternalInterface.call(getStreamPathMethod("decodeError"), err);
            }
          }
        });
        streamBuffer = lastElement;
      }
    }
*/
    // call out to javascript that there was an error in the stream
    private function errorReceived(ioError:IOErrorEvent):void {
      //stop the timers
      connectionTimer.stop();
      transmissionTimer.stop();

      ExternalInterface.call(getStreamPathMethod("streamError"), ioError.text);
    }

    private function securityErrorHandler(event:SecurityErrorEvent):void {
      ExternalInterface.call("console.error", JSON.encode(event));
    }
  }
}