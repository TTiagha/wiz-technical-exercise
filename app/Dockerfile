# =============================================================================
# DOCKERFILE - Wiz Todo App Container
# =============================================================================
# This builds a container image for the todo application.
# The wizexercise.txt file is REQUIRED by the exercise to prove you built this.
# =============================================================================

FROM node:16-alpine

# Create app directory
WORKDIR /app

# Copy package files first (better layer caching)
COPY package*.json ./

# Install dependencies
RUN npm install --production

# Copy application code
COPY . .

# REQUIRED BY EXERCISE: Create wizexercise.txt with candidate name
# This proves the candidate built this specific image
RUN echo "Tem Muya Tiagha" > /app/wizexercise.txt

# Create non-root user for security
RUN addgroup -g 1001 -S nodejs && \
    adduser -S nodejs -u 1001

# Change ownership and switch to non-root user
RUN chown -R nodejs:nodejs /app
USER nodejs

# Expose port
EXPOSE 3000

# Health check
HEALTHCHECK --interval=30s --timeout=3s --start-period=5s --retries=3 \
    CMD wget --no-verbose --tries=1 --spider http://localhost:3000/health || exit 1

# Start application
CMD ["node", "server.js"]
