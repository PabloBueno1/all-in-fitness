"""Added hashed_password to Users

Revision ID: 119f6521ac60
Revises: cf69df377203
Create Date: 2025-02-06 03:22:04.228250

"""
from typing import Sequence, Union

from alembic import op
import sqlalchemy as sa
from sqlalchemy.dialects import postgresql

# revision identifiers, used by Alembic.
revision: str = '119f6521ac60'
down_revision: Union[str, None] = 'cf69df377203'
branch_labels: Union[str, Sequence[str], None] = None
depends_on: Union[str, Sequence[str], None] = None


def upgrade() -> None:
    op.add_column("users", sa.Column("hashed_password", sa.String(), nullable=False, server_default=""))


def downgrade() -> None:
    op.drop_column("users", "hashed_password")
