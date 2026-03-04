using Microsoft.Azure.Cosmos;
using Microsoft.Extensions.Diagnostics.HealthChecks;
using System;
using System.Threading;
using System.Threading.Tasks;

namespace CapstoneWebApp
{
    public class CosmosHealthCheck : IHealthCheck
    {
        private readonly Container _container;

        public CosmosHealthCheck(Container container)
        {
            _container = container ?? throw new ArgumentNullException(nameof(container));
        }

        public async Task<HealthCheckResult> CheckHealthAsync(HealthCheckContext context, CancellationToken cancellationToken = default)
        {
            try
            {
                using var iterator = _container.GetItemQueryIterator<object>("SELECT TOP 1 c.id FROM c");

                if (iterator.HasMoreResults)
                {
                    var response = await iterator.ReadNextAsync(cancellationToken);
                }

                return HealthCheckResult.Healthy("Cosmos DB reachable");
            }
            catch (Exception ex)
            {
                return HealthCheckResult.Unhealthy("Cosmos DB check failed", ex);
            }
        }
    }
}
