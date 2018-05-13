provider "aws" {
  region = "${var.aws_region}"
}

resource "aws_api_gateway_rest_api" "vaddy" {
  name = "VAddyProxyAutoConfig"
}

resource "aws_api_gateway_resource" "pac" {
  rest_api_id = "${aws_api_gateway_rest_api.vaddy.id}"
  parent_id = "${aws_api_gateway_rest_api.vaddy.root_resource_id}"
  path_part = "pac"
}

resource "aws_api_gateway_method" "get_pac" {
  rest_api_id = "${aws_api_gateway_rest_api.vaddy.id}"
  resource_id = "${aws_api_gateway_resource.pac.id}"
  http_method = "GET"
  authorization = "NONE"
  request_parameters = {
    "method.request.querystring.host" = true
  }
}

resource "aws_api_gateway_integration" "get_pac" {
  rest_api_id = "${aws_api_gateway_rest_api.vaddy.id}"
  resource_id = "${aws_api_gateway_resource.pac.id}"
  http_method = "${aws_api_gateway_method.get_pac.http_method}"
  type = "MOCK"
  passthrough_behavior = "NEVER"
  request_templates {
    "application/json" = "{\"statusCode\": 200}"
  }
}

resource "aws_api_gateway_method_response" "200" {
  rest_api_id = "${aws_api_gateway_rest_api.vaddy.id}"
  resource_id = "${aws_api_gateway_resource.pac.id}"
  http_method = "${aws_api_gateway_method.get_pac.http_method}"
  status_code = "200"
  response_models = {
    "application/x-ns-proxy-autoconfig" = "Empty"
  }
}

data "template_file" "response_vm" {
  template = "${file("response.vm")}"
  vars {
    proxy = "${var.vaddy_proxy}"
  }
}

resource "aws_api_gateway_integration_response" "get_pac" {
  rest_api_id = "${aws_api_gateway_rest_api.vaddy.id}"
  resource_id = "${aws_api_gateway_resource.pac.id}"
  http_method = "${aws_api_gateway_method.get_pac.http_method}"
  status_code = "${aws_api_gateway_method_response.200.status_code}"
  response_templates {
    "application/x-ns-proxy-autoconfig" = "${data.template_file.response_vm.rendered}"
  }
}

resource "aws_api_gateway_deployment" "vaddy" {
  depends_on = [
    "aws_api_gateway_resource.pac",
    "aws_api_gateway_method.get_pac",
    "aws_api_gateway_method_response.200",
    "aws_api_gateway_integration.get_pac",
    "aws_api_gateway_integration_response.get_pac",
  ]
  rest_api_id = "${aws_api_gateway_rest_api.vaddy.id}"
  stage_name = "vaddy"
}

output "pac" {
  value = "${aws_api_gateway_deployment.vaddy.invoke_url}/${aws_api_gateway_resource.pac.path_part}"
}

