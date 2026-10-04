# Chapter 05 lab: a reference to a variable that does not exist - terraform validate refuses it.
output "lab_broken" {
  value = var.lab_does_not_exist
}
