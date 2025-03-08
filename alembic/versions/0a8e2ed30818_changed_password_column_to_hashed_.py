"""Changed password column to hashed_password

Revision ID: 0a8e2ed30818
Revises: b265faa59c45
Create Date: 2025-02-06 05:05:37.620474

"""
from typing import Sequence, Union

from alembic import op
import sqlalchemy as sa
from sqlalchemy.dialects import postgresql

# revision identifiers, used by Alembic.
revision: str = '0a8e2ed30818'
down_revision: Union[str, None] = 'b265faa59c45'
branch_labels: Union[str, Sequence[str], None] = None
depends_on: Union[str, Sequence[str], None] = None


def upgrade():
    # Add new column hashed_password
    op.add_column('users', sa.Column('hashed_password', sa.String(), nullable=False, server_default=''))

    # Copy data from old password column to new hashed_password column (temporary step)
    op.execute("UPDATE users SET hashed_password = password")

    # Drop the old password column
    op.drop_column('users', 'password')


def downgrade():
    # Recreate the old password column
    op.add_column('users', sa.Column('password', sa.String(), nullable=False, server_default=''))

    # Copy data back (not safe for hashing, but required for rollback)
    op.execute("UPDATE users SET password = hashed_password")

    # Drop hashed_password column
    op.drop_column('users', 'hashed_password')