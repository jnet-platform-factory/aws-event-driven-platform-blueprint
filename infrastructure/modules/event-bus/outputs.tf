output "event_bus_name" {
  description = "Name of the event bus"
  value       = aws_cloudwatch_event_bus.this.name
}

output "event_bus_arn" {
  description = "ARN of the event bus"
  value       = aws_cloudwatch_event_bus.this.arn
}
