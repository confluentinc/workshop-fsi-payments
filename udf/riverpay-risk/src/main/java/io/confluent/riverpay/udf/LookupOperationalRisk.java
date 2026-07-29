package io.confluent.riverpay.udf;

import java.net.URI;
import java.net.URLEncoder;
import java.net.http.HttpClient;
import java.net.http.HttpRequest;
import java.net.http.HttpResponse;
import java.nio.charset.StandardCharsets;
import java.time.Duration;
import org.apache.flink.table.functions.FunctionContext;
import org.apache.flink.table.functions.ScalarFunction;

/**
 * Looks up operational exception probability from the shared RiverPay Risk API.
 *
 * Returns a pipe-delimited payload: {@code risk_score|risk_reason}
 * so Flink SQL can split once without a second HTTP call.
 *
 * Connection name used in CREATE FUNCTION USING CONNECTIONS must match the
 * prefix passed to {@code getJobParameter} (here: {@code riverpay_risk_api}).
 */
public class LookupOperationalRisk extends ScalarFunction {

  private static final Duration TIMEOUT = Duration.ofMillis(2000);

  private transient HttpClient httpClient;
  private transient String endpoint;
  private transient String apiKey;

  @Override
  public void open(FunctionContext context) throws Exception {
    this.endpoint = context.getJobParameter("riverpay_risk_api.endpoint", null);
    this.apiKey = context.getJobParameter("riverpay_risk_api.api-key", null);
    this.httpClient =
        HttpClient.newBuilder().connectTimeout(Duration.ofSeconds(2)).build();
  }

  public String eval(Double amount, String segment, String accountTier) {
    if (endpoint == null || endpoint.isBlank()) {
      return "0.28|risk_api_endpoint_missing";
    }
    if (amount == null) {
      return "0.28|routine_instant_credit_transfer";
    }

    try {
      String base = endpoint.endsWith("/") ? endpoint.substring(0, endpoint.length() - 1) : endpoint;
      // Prefer GET /v1/risk for simple query-string UDF calls.
      String path = base.contains("/v1/risk") ? base : base + "/v1/risk";
      String uri =
          path
              + "?amount="
              + URLEncoder.encode(Double.toString(amount), StandardCharsets.UTF_8)
              + "&segment="
              + URLEncoder.encode(nullToEmpty(segment), StandardCharsets.UTF_8)
              + "&account_tier="
              + URLEncoder.encode(nullToEmpty(accountTier), StandardCharsets.UTF_8);

      HttpRequest.Builder builder =
          HttpRequest.newBuilder()
              .uri(URI.create(uri))
              .timeout(TIMEOUT)
              .GET();

      if (apiKey != null && !apiKey.isBlank()) {
        builder.header("Authorization", "Bearer " + apiKey);
      }

      HttpResponse<String> response =
          httpClient.send(builder.build(), HttpResponse.BodyHandlers.ofString());
      if (response.statusCode() < 200 || response.statusCode() >= 300) {
        return "0.28|risk_api_http_" + response.statusCode();
      }
      return parseToPipe(response.body());
    } catch (Exception e) {
      return "0.28|risk_api_error";
    }
  }

  static String parseToPipe(String body) {
    if (body == null || body.isBlank()) {
      return "0.28|routine_instant_credit_transfer";
    }
    String score = extractJsonString(body, "risk_score");
    String reason = extractJsonString(body, "risk_reason");
    if (score == null) {
      score = "0.28";
    }
    if (reason == null || reason.isBlank()) {
      reason = "routine_instant_credit_transfer";
    }
    return score + "|" + reason;
  }

  /** Minimal JSON field extractor (avoids pulling a JSON library into the UDF JAR). */
  static String extractJsonString(String json, String field) {
    String key = "\"" + field + "\"";
    int i = json.indexOf(key);
    if (i < 0) {
      return null;
    }
    int colon = json.indexOf(':', i + key.length());
    if (colon < 0) {
      return null;
    }
    int j = colon + 1;
    while (j < json.length() && Character.isWhitespace(json.charAt(j))) {
      j++;
    }
    if (j >= json.length()) {
      return null;
    }
    if (json.charAt(j) == '"') {
      int end = json.indexOf('"', j + 1);
      if (end < 0) {
        return null;
      }
      return json.substring(j + 1, end);
    }
    int end = j;
    while (end < json.length()
        && (Character.isDigit(json.charAt(end))
            || json.charAt(end) == '.'
            || json.charAt(end) == '-'
            || json.charAt(end) == 'e'
            || json.charAt(end) == 'E'
            || json.charAt(end) == '+')) {
      end++;
    }
    return json.substring(j, end);
  }

  private static String nullToEmpty(String s) {
    return s == null ? "" : s;
  }
}
