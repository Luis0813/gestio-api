# == Tenant scoping helpers
#
# Every business record belongs to exactly one user (multi-tenant app). These
# helpers guarantee that a request can only ever reach rows owned by
# `current_user`. Looking a record up through the association raises
# `ActiveRecord::RecordNotFound` (rendered as 404) when the id belongs to
# another company, so ids of other tenants are never leaked nor modified.
module TenantScoped
  private

  # Returns the association proxy for the given model name, e.g.
  # `scoped(:products)` => `current_user.products`.
  def scoped(model)
    current_user.public_send(model)
  end

  # Finds a record strictly inside the current user's rows.
  def find_scoped(model, id)
    current_user.public_send(model).find(id)
  end
end
