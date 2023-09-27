package example;

import com.amazonaws.services.lambda.runtime.Context;
import com.amazonaws.services.lambda.runtime.RequestHandler;

public class HelloWorldHandler implements RequestHandler<Request, Response> {

    public Response handleRequest(Request request, Context context) {
        System.out.println("NOTE - in HelloWorldHandler::handleRequest()");
        String greetings = "Greetings from Austin's first Terraform Project";
        return new Response(greetings);
    }
}

